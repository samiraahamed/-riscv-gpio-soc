// ============================================================
// RISC-V RV32I SoC with Memory-Mapped GPIO Controller
// Author: Your Name
// Description: Full CPU + GPIO peripheral built from scratch
// ============================================================

// ── ALU ──────────────────────────────────────────────────────
module alu_32bit(
    input [31:0] a, b,
    input [2:0]  op,
    output reg [31:0] result,
    output zero
);
    assign zero = (result == 0);
    always @(*) case(op)
        3'b000: result = a + b;
        3'b001: result = a - b;
        3'b010: result = a & b;
        3'b011: result = a | b;
        3'b100: result = a ^ b;
        3'b101: result = ($signed(a) < $signed(b)) ? 1 : 0;
        3'b110: result = a << b[4:0];
        3'b111: result = a >> b[4:0];
        default: result = 0;
    endcase
endmodule

// ── Register File ─────────────────────────────────────────────
module register_file(
    input clk, reset,
    input  [4:0]  rs1_addr, rs2_addr,
    output [31:0] rs1_data, rs2_data,
    input  [4:0]  rd_addr,
    input  [31:0] rd_data,
    input         we
);
    reg [31:0] regs[0:31];
    integer i;
    assign rs1_data = (rs1_addr==0) ? 0 : regs[rs1_addr];
    assign rs2_data = (rs2_addr==0) ? 0 : regs[rs2_addr];
    always @(posedge clk or posedge reset)
        if(reset) begin
            for(i=0;i<32;i=i+1) regs[i] <= 0;
            regs[10] <= 32'h2000; // x10 = GPIO base address
        end
        else if(we && rd_addr!=0) regs[rd_addr] <= rd_data;
endmodule

// ── Instruction Decoder ───────────────────────────────────────
module decoder(
    input  [31:0] instr,
    output [4:0]  rs1, rs2, rd,
    output [2:0]  funct3,
    output [6:0]  funct7, opcode,
    output [31:0] imm_i, imm_s,
    output is_rtype, is_itype, is_store, reg_write
);
    assign opcode    = instr[6:0];
    assign rd        = instr[11:7];
    assign funct3    = instr[14:12];
    assign rs1       = instr[19:15];
    assign rs2       = instr[24:20];
    assign funct7    = instr[31:25];
    assign imm_i     = {{20{instr[31]}}, instr[31:20]};
    assign imm_s     = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    assign is_rtype  = (opcode == 7'b0110011);
    assign is_itype  = (opcode == 7'b0010011);
    assign is_store  = (opcode == 7'b0100011);
    assign reg_write = is_rtype | is_itype;
endmodule

// ── ALU Control ───────────────────────────────────────────────
module alu_control(
    input [2:0] funct3,
    input [6:0] funct7,
    input is_rtype,
    output reg [2:0] alu_op
);
    always @(*) begin
        if(is_rtype) case(funct3)
            3'b000: alu_op = (funct7==7'b0100000) ? 3'b001 : 3'b000;
            3'b110: alu_op = 3'b011;
            3'b111: alu_op = 3'b010;
            3'b100: alu_op = 3'b100;
            3'b010: alu_op = 3'b101;
            3'b001: alu_op = 3'b110;
            3'b101: alu_op = 3'b111;
            default: alu_op = 3'b000;
        endcase
        else alu_op = 3'b000;
    end
endmodule

// ── Instruction Memory (ROM) ──────────────────────────────────
module imem(
    input  [31:0] addr,
    output [31:0] instr
);
    reg [31:0] mem[0:15];
    integer idx;
    initial begin
        for(idx=0;idx<16;idx=idx+1)
            mem[idx] = 32'b000000000000_00000_000_00000_0010011; // NOP
        // x10 = 0x2000 preloaded in register file
        // ADDI x1, x0, 255   → x1 = 0xFF
        mem[0] = 32'b000011111111_00000_000_00001_0010011;
        // ADDI x2, x0, 85    → x2 = 0x55
        mem[1] = 32'b000001010101_00000_000_00010_0010011;
        // ADDI x3, x0, 170   → x3 = 0xAA
        mem[2] = 32'b000010101010_00000_000_00011_0010011;
        // SW x1, 4(x10)      → GPIO_DIR = 0xFF (all output)
        mem[3] = 32'b0000000_00001_01010_010_00100_0100011;
        // SW x2, 0(x10)      → GPIO_DATA = 0x55
        mem[4] = 32'b0000000_00010_01010_010_00000_0100011;
        // SW x3, 0(x10)      → GPIO_DATA = 0xAA
        mem[5] = 32'b0000000_00011_01010_010_00000_0100011;
        // SW x1, 0(x10)      → GPIO_DATA = 0xFF
        mem[6] = 32'b0000000_00001_01010_010_00000_0100011;
        // SW x0, 0(x10)      → GPIO_DATA = 0x00
        mem[7] = 32'b0000000_00000_01010_010_00000_0100011;
        // XOR x4, x2, x3     → x4 = 0x55^0xAA = 0xFF
        mem[8] = 32'b0000000_00011_00010_100_00100_0110011;
        // AND x5, x2, x3     → x5 = 0x00
        mem[9] = 32'b0000000_00011_00010_111_00101_0110011;
        // OR  x6, x2, x3     → x6 = 0xFF
        mem[10]= 32'b0000000_00011_00010_110_00110_0110011;
        // SW x4, 0(x10)      → GPIO_DATA = 0xFF
        mem[11]= 32'b0000000_00100_01010_010_00000_0100011;
        // SW x5, 0(x10)      → GPIO_DATA = 0x00
        mem[12]= 32'b0000000_00101_01010_010_00000_0100011;
        // SW x6, 0(x10)      → GPIO_DATA = 0xFF
        mem[13]= 32'b0000000_00110_01010_010_00000_0100011;
    end
    assign instr = mem[addr[31:2]];
endmodule

// ── GPIO Controller ───────────────────────────────────────────
module gpio_ctrl(
    input        clk, reset,
    input [31:0] bus_addr, bus_wdata,
    input        bus_we,
    output [7:0] gpio_out,
    output [7:0] gpio_dir
);
    reg [31:0] data_reg, dir_reg;
    always @(posedge clk or posedge reset) begin
        if(reset) begin data_reg<=0; dir_reg<=0; end
        else if(bus_we) begin
            if(bus_addr==32'h2000) data_reg <= bus_wdata;
            if(bus_addr==32'h2004) dir_reg  <= bus_wdata;
        end
    end
    assign gpio_out = data_reg[7:0] & dir_reg[7:0];
    assign gpio_dir = dir_reg[7:0];
endmodule

// ── Top-Level SoC ─────────────────────────────────────────────
module soc(
    input  clk, reset,
    output [7:0] gpio_out,
    output [7:0] gpio_dir
);
    reg  [31:0] pc;
    wire [31:0] instr, imm_i, imm_s, rs1_data, rs2_data, alu_result;
    wire [4:0]  rs1, rs2, rd;
    wire [2:0]  funct3, alu_op;
    wire [6:0]  funct7, opcode;
    wire        is_rtype, is_itype, is_store, reg_write, zero;

    always @(posedge clk or posedge reset)
        if(reset) pc <= 0;
        else      pc <= pc + 4;

    imem        IM  (pc, instr);
    decoder     DC  (instr, rs1, rs2, rd, funct3, funct7, opcode,
                     imm_i, imm_s, is_rtype, is_itype, is_store, reg_write);
    alu_control AC  (funct3, funct7, is_rtype, alu_op);

    wire [31:0] alu_b = is_store ? imm_s :
                        is_itype ? imm_i : rs2_data;

    register_file RF (clk, reset,
                      rs1, rs2, rs1_data, rs2_data,
                      rd, alu_result, reg_write);
    alu_32bit     ALU(rs1_data, alu_b, alu_op, alu_result, zero);
    gpio_ctrl     GPIO(clk, reset,
                       alu_result, rs2_data, is_store,
                       gpio_out, gpio_dir);
endmodule
