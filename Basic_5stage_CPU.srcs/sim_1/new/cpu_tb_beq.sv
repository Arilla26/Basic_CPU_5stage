`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/27/2025 08:11:33 AM
// Design Name: 
// Module Name: cpu_tb_beq
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


//==============================================================
// Testbench: cpu_tb_beq (SystemVerilog)
// - Mục tiêu: kiểm tra BEQ cả 2 trường hợp: TAKEN và NOT-TAKEN
// - Không dùng file instr.mem: nạp lệnh trực tiếp vào dut.u_if.instr_mem[]
//==============================================================
module cpu_tb_beq;

  timeunit 1ns; timeprecision 1ps;

  // Clock & Reset
  logic clk;
  logic rst;

  // DUT
  cpu_top dut (
    .clk(clk),
    .rst(rst)
  );

  // Clock 100 MHz
  localparam real CLK_PERIOD = 10.0;
  always #(CLK_PERIOD/2.0) clk = ~clk;

  // ---------- Helper encoders (RV32I) ----------
  // addi rd, rs1, imm12 (sign-extended)
  function automatic logic [31:0] enc_addi(input int rd, input int rs1, input int imm12);
    logic [31:0] u;
    logic [11:0] imm12u;
    begin
      imm12u = imm12[11:0];
      u = 32'b0;
      u[6:0]   = 7'b0010011;          // opcode
      u[11:7]  = rd[4:0];             // rd
      u[14:12] = 3'b000;              // funct3
      u[19:15] = rs1[4:0];            // rs1
      u[31:20] = imm12u;              // imm[11:0]
      return u;
    end
  endfunction

  // add rd, rs1, rs2
  function automatic logic [31:0] enc_add(input int rd, input int rs1, input int rs2);
    logic [31:0] u;
    begin
      u = 32'b0;
      u[6:0]    = 7'b0110011;         // opcode
      u[11:7]   = rd[4:0];            // rd
      u[14:12]  = 3'b000;             // funct3
      u[19:15]  = rs1[4:0];           // rs1
      u[24:20]  = rs2[4:0];           // rs2
      u[31:25]  = 7'b0000000;         // funct7 (ADD)
      return u;
    end
  endfunction

  // beq rs1, rs2, imm_bytes  (imm phải là bội số của 2; PC-relative)
  function automatic logic [31:0] enc_beq(input int rs1, input int rs2, input int imm_bytes);
    // BEQ: opcode=1100011, funct3=000
    // imm encoding: [12|10:5|4:1|11] -> bits [31|30:25|11:8|7], LSB luôn 0
    logic [31:0] u;
    int  imm;           // dùng đơn vị byte
    logic       b12, b11;
    logic [5:0] b10_5;  // 6 bits
    logic [3:0] b4_1;   // 4 bits
    begin
      imm = imm_bytes;
      // ASSERT nhỏ: nên bội số 2
      if (imm % 2 != 0) $display("WARN: BEQ imm should be even; got %0d", imm);

      b12   = (imm >> 12) & 1;
      b10_5 = (imm >> 5) & 6'h3F;
      b4_1  = (imm >> 1) & 4'hF;
      b11   = (imm >> 11) & 1;

      u = 32'b0;
      u[6:0]    = 7'b1100011;       // opcode
      u[14:12]  = 3'b000;           // funct3 for BEQ
      u[19:15]  = rs1[4:0];
      u[24:20]  = rs2[4:0];
      u[31]     = b12;
      u[30:25]  = b10_5;
      u[11:8]   = b4_1;
      u[7]      = b11;
      return u;
    end
  endfunction

  // ---------- Pretty print ----------
  task automatic show(input string tag);
    $display("---- %s ---- time=%0t", tag, $time);
    $display("PC          = 0x%08h", dut.u_if.pc_out);
    $display("inst        = 0x%08h", dut.u_if.inst);
    $display("x1=%0d x2=%0d x3=%0d x5=%0d x6=%0d x7=%0d",
             dut.u_id.regfile[1], dut.u_id.regfile[2], dut.u_id.regfile[3],
             dut.u_id.regfile[5], dut.u_id.regfile[6], dut.u_id.regfile[7]);
  endtask

  task automatic step(input string tag);
    @(posedge clk); #1; show(tag);
  endtask

  task automatic CHECK_EQ(input string what, input int got, input int exp);
    if (got !== exp) begin
      $display("ASSERT FAIL: %s got=%0d exp=%0d  t=%0t", what, got, exp, $time);
      $display("-------------------------------------");
      $fatal(1);
    end
    else begin
      $display("ASSERT PASS: %s == %0d", what, exp);
      $display("-------------------------------------");
    end
  endtask

  // ---------- Preload chương trình kiểm thử BEQ ----------
  task automatic preload_program;
    // Layout (địa chỉ tính theo PC: 0,4,8,12,...):
    // 0: addi x1,x0,5
    // 1: addi x2,x0,5
    // 2: beq  x1,x2, +8    -> nhảy tới PC=16 (skip lệnh tại PC=12)
    // 3: addi x3,x0,111    -> PHẢI BỊ BỎ QUA nếu branch taken
    // 4: addi x3,x0,9      -> ĐÍCH NHẢY (x3=9)
    // 5: addi x5,x0,3
    // 6: addi x6,x0,7
    // 7: beq  x5,x6, +8    -> KHÔNG nhảy (vì 3 != 7)
    // 8: addi x7,x0,11     -> PHẢI CHẠY (x7=11)
    // 9: addi x7,x0,22     -> ĐÍCH NHẢY (nếu lẽ ra nhảy) -> PHẢI BỊ BỎ QUA

    // Nạp trực tiếp vào instr_mem
    dut.u_if.instr_mem[0] = enc_addi(1, 0, 5);
    dut.u_if.instr_mem[1] = enc_addi(2, 0, 5);
    dut.u_if.instr_mem[2] = enc_beq (1, 2, 8);     // nhảy +8 bytes từ PC=8 -> PC=16
    dut.u_if.instr_mem[3] = enc_addi(3, 0, 111);   // sẽ bị skip nếu branch taken
    dut.u_if.instr_mem[4] = enc_addi(3, 0, 9);     // đích nhảy: x3=9

    dut.u_if.instr_mem[5] = enc_addi(5, 0, 3);
    dut.u_if.instr_mem[6] = enc_addi(6, 0, 7);
    dut.u_if.instr_mem[7] = enc_beq (5, 6, 8);     // NOT-TAKEN, đi tiếp PC+4
    dut.u_if.instr_mem[8] = enc_addi(7, 0, 11);    // phải thực thi: x7=11
    dut.u_if.instr_mem[9] = enc_addi(7, 0, 22);    // đích nhảy giả định -> phải bị bỏ qua
  endtask

  // ---------- Main ----------
  initial begin
    clk = 0;
    rst = 1;

    // Nạp chương trình trước khi thả reset
    preload_program();

    // Giữ reset 2 chu kỳ
    step("reset posedge 1");
    step("reset posedge 2");

    // Thả reset
    rst = 0;
    $display("== RELEASE RESET ==");

    // Chu kỳ 1: addi x1,5
    step("cycle 1");
    CHECK_EQ("x1", dut.u_id.regfile[1], 5);

    // Chu kỳ 2: addi x2,5
    step("cycle 2");
    CHECK_EQ("x2", dut.u_id.regfile[2], 5);

    // Chu kỳ 3: beq x1,x2,+8  (TAKEN) -> lệnh tại PC=12 phải bị bỏ qua
    step("cycle 3 (BEQ taken)");

    // Chu kỳ 4: đích nhảy PC=16 -> addi x3,9
    step("cycle 4 (target)");
    CHECK_EQ("x3 (after branch target)", dut.u_id.regfile[3], 9);

    // Chu kỳ 5: addi x5,3
    step("cycle 5");
    CHECK_EQ("x5", dut.u_id.regfile[5], 3);

    // Chu kỳ 6: addi x6,7
    step("cycle 6");
    CHECK_EQ("x6", dut.u_id.regfile[6], 7);

    // Chu kỳ 7: beq x5,x6,+8  (NOT-TAKEN)
    step("cycle 7 (BEQ not taken)");

    // Chu kỳ 8: PC+4 -> addi x7,11 phải chạy
    step("cycle 8 (fall-through)");
    CHECK_EQ("x7 (fall-through)", dut.u_id.regfile[7], 11);

    // Chu kỳ 9: (đáng lẽ là đích nhảy nếu taken) -> phải bị bỏ qua vì NOT-TAKEN
    step("cycle 9");

    $display("== BEQ TESTS PASSED ==");
    $finish;
  end

endmodule
