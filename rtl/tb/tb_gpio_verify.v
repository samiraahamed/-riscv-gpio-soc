// ============================================================
// Verification Testbench — GPIO Controller
// 27-test automated scoreboard
// ============================================================
module tb_gpio_verify;
    reg        clk, reset;
    reg [31:0] bus_addr, bus_wdata;
    reg        bus_we;
    wire [7:0] gpio_out, gpio_dir, gpio_in_reg;

    gpio_ctrl DUT(clk, reset, bus_addr, bus_wdata, bus_we,
                  gpio_out, gpio_dir, gpio_in_reg);

    initial clk = 0;
    always #5 clk = ~clk;

    integer tests_run, tests_pass, tests_fail;

    task check;
        input [7:0]  actual, expected;
        input [80:0] test_name;
        begin
            tests_run = tests_run + 1;
            if(actual === expected) begin
                $display("  PASS | %-30s | got 0x%h", test_name, actual);
                tests_pass = tests_pass + 1;
            end else begin
                $display("  FAIL | %-30s | got 0x%h, expect 0x%h",
                         test_name, actual, expected);
                tests_fail = tests_fail + 1;
            end
        end
    endtask

    task bus_write;
        input [31:0] addr, data;
        begin
            bus_addr=addr; bus_wdata=data; bus_we=1;
            @(posedge clk); #1;
            bus_we=0;
        end
    endtask

    task test_reset;
        begin
            $display("\n[Suite 1] Reset state");
            check(gpio_out, 8'h00, "OUT after reset = 0x00");
            check(gpio_dir, 8'h00, "DIR after reset = 0x00");
        end
    endtask

    task test_dir_register;
        begin
            $display("\n[Suite 2] Direction register");
            bus_write(32'h2004, 32'hFF);
            check(gpio_dir, 8'hFF, "DIR=0xFF all output");
            bus_write(32'h2004, 32'h0F);
            check(gpio_dir, 8'h0F, "DIR=0x0F lower nibble out");
            bus_write(32'h2004, 32'h00);
            check(gpio_dir, 8'h00, "DIR=0x00 all input");
        end
    endtask

    task test_data_register;
        begin
            $display("\n[Suite 3] Data register + DIR gating");
            bus_write(32'h2004, 32'hFF);
            bus_write(32'h2000, 32'h55);
            check(gpio_out, 8'h55, "OUT=0x55 alternating A");
            bus_write(32'h2000, 32'hAA);
            check(gpio_out, 8'hAA, "OUT=0xAA alternating B");
            bus_write(32'h2000, 32'hFF);
            check(gpio_out, 8'hFF, "OUT=0xFF all on");
            bus_write(32'h2000, 32'h00);
            check(gpio_out, 8'h00, "OUT=0x00 all off");
        end
    endtask

    task test_dir_gating;
        begin
            $display("\n[Suite 4] DIR gating");
            bus_write(32'h2000, 32'hFF);
            bus_write(32'h2004, 32'hF0);
            check(gpio_out, 8'hF0, "DIR=0xF0 gates upper nibble");
            bus_write(32'h2004, 32'h0F);
            check(gpio_out, 8'h0F, "DIR=0x0F gates lower nibble");
            bus_write(32'h2004, 32'hAA);
            check(gpio_out, 8'hAA, "DIR=0xAA gates alt pins");
        end
    endtask

    task test_patterns;
        begin
            $display("\n[Suite 5] Walking 1 and Walking 0");
            bus_write(32'h2004, 32'hFF);
            bus_write(32'h2000, 32'h01); check(gpio_out,8'h01,"Walking 1: bit 0");
            bus_write(32'h2000, 32'h02); check(gpio_out,8'h02,"Walking 1: bit 1");
            bus_write(32'h2000, 32'h04); check(gpio_out,8'h04,"Walking 1: bit 2");
            bus_write(32'h2000, 32'h08); check(gpio_out,8'h08,"Walking 1: bit 3");
            bus_write(32'h2000, 32'h10); check(gpio_out,8'h10,"Walking 1: bit 4");
            bus_write(32'h2000, 32'h20); check(gpio_out,8'h20,"Walking 1: bit 5");
            bus_write(32'h2000, 32'h40); check(gpio_out,8'h40,"Walking 1: bit 6");
            bus_write(32'h2000, 32'h80); check(gpio_out,8'h80,"Walking 1: bit 7");
            bus_write(32'h2000, 32'hFE); check(gpio_out,8'hFE,"Walking 0: bit 0 off");
            bus_write(32'h2000, 32'hFD); check(gpio_out,8'hFD,"Walking 0: bit 1 off");
            bus_write(32'h2000, 32'hFB); check(gpio_out,8'hFB,"Walking 0: bit 2 off");
            bus_write(32'h2000, 32'hF7); check(gpio_out,8'hF7,"Walking 0: bit 3 off");
        end
    endtask

    task test_wrong_addr;
        begin
            $display("\n[Suite 6] Wrong address (no effect)");
            bus_write(32'h2004, 32'hFF);
            bus_write(32'h2000, 32'h55);
            bus_write(32'h3000, 32'hFF);
            check(gpio_out, 8'h55, "Wrong addr ignored OUT");
            bus_write(32'h1000, 32'h00);
            check(gpio_dir, 8'hFF, "Wrong addr ignored DIR");
        end
    endtask

    task test_input_reg;
        begin
            $display("\n[Suite 7] Input register read-back");
            check(gpio_in_reg, 8'hA5, "gpio_in_reg = 0xA5");
        end
    endtask

    initial begin
        tests_run=0; tests_pass=0; tests_fail=0;
        bus_addr=0; bus_wdata=0; bus_we=0;
        $display("================================================");
        $display("   GPIO Controller — Verification Suite");
        $display("================================================");
        $display("  Result | Test                           | Value");
        $display("---------|--------------------------------|-------");
        reset=1; @(posedge clk); #1; reset=0;
        test_reset;
        test_dir_register;
        test_data_register;
        test_dir_gating;
        test_patterns;
        test_wrong_addr;
        test_input_reg;
        $display("\n================================================");
        $display("  RESULTS: %0d/%0d passed, %0d failed",
                 tests_pass, tests_run, tests_fail);
        if(tests_fail==0)
            $display("  ALL TESTS PASSED - GPIO verified!");
        else
            $display("  SOME TESTS FAILED - check above");
        $display("================================================");
        $finish;
    end
endmodule
