`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/22/2025 09:57:35 AM
// Design Name: 
// Module Name: cpu_tb
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
// Testbench: cpu_tb (SystemVerilog)
// - Thiết kế: CPU tuần tự 5-stage (không pipeline)
// - Yêu cầu: file instr.mem nằm trong Simulation Sources
//   Chương trình mẫu (instr.mem):
//     0: addi x1, x0, 5
//     1: addi x2, x0, 7
//     2: add  x3, x1, x2
//     3: sw   x3, 0(x0)
//     4: lw   x4, 0(x0)
//     5: nop
//==============================================================
module cpu_tb;
  timeunit 1ns; timeprecision 1ps;

  // Clock & Reset
  logic clk;
  logic rst;

  // DUT
  cpu_top dut (
    .clk(clk),
    .rst(rst)
  );

  // Clock 100 MHz (chu kỳ 10 ns)
  localparam real CLK_PERIOD = 10.0;
  always #(CLK_PERIOD/2.0) clk = ~clk;

  // (Tuỳ chọn) dump VCD: bật khi compile kèm +define+VCD
  initial begin
`ifdef VCD
    $dumpfile("cpu_tb.vcd");
    $dumpvars(0, cpu_tb);
`endif
  end

  //============================================================
  // TIỆN ÍCH IN TRẠNG THÁI / ASSERT
  //============================================================
  task automatic show_state(input string tag);
    $display("---- %s ---- time=%0t", tag, $time);
    $display("PC          = 0x%08h", dut.u_if.pc_out);
    $display("inst        = 0x%08h", dut.u_if.inst);
    // Một số thanh ghi quan trọng
    $display("x1=%0d x2=%0d x3=%0d x4=%0d",
             dut.u_id.regfile[1],
             dut.u_id.regfile[2],
             dut.u_id.regfile[3],
             dut.u_id.regfile[4]);
  endtask

  // Chờ 1 chu kỳ (1 posedge) rồi in trạng thái
  task automatic step_cycle(input string label);
    @(posedge clk);
    #1; // cho tín hiệu ổn định một chút
    show_state(label);
  endtask

  // ASSERT tiện lợi
  task automatic check_equal(input string what, input int got, input int exp);
    if (got !== exp) begin
      $display("ASSERT FAIL: %s  got=%0d  exp=%0d  (time=%0t)", what, got, exp, $time);
      $display("----------------------------------------");
      $fatal(1);
    end else begin
      $display("ASSERT PASS: %s == %0d", what, exp);
      $display("----------------------------------------");
    end
  endtask

  //============================================================
  // KỊCH BẢN CHÍNH
  //============================================================
  initial begin
    clk = 1'b0;
    rst = 1'b1;

    // Giữ reset 2 chu kỳ để IF init PC=0
    step_cycle("after reset posedge 1");
    step_cycle("after reset posedge 2");

    // Thả reset
    rst = 1'b0;
    $display("== RELEASE RESET ==");

    // Chu kỳ 1: lệnh 0 -> addi x1, x0, 5  => x1=5
    step_cycle("cycle 1 (expect x1=5)");
    check_equal("x1", dut.u_id.regfile[1], 5);

    // Chu kỳ 2: lệnh 1 -> addi x2, x0, 7  => x2=7
    step_cycle("cycle 2 (expect x2=7)");
    check_equal("x2", dut.u_id.regfile[2], 7);

    // Chu kỳ 3: lệnh 2 -> add  x3, x1, x2 => x3=12
    step_cycle("cycle 3 (expect x3=12)");
    check_equal("x3", dut.u_id.regfile[3], 12);

    // Chu kỳ 4: lệnh 3 -> sw   x3, 0(x0)  => mem[0]=12 (ghi tại posedge)
    step_cycle("cycle 4 (expect mem[0]=12)");
    check_equal("mem[0]", dut.u_mem.data_mem[0], 12);

    // Chu kỳ 5: lệnh 4 -> lw   x4, 0(x0)  => x4=12
    step_cycle("cycle 5 (expect x4=12)");
    check_equal("x4", dut.u_id.regfile[4], 12);

    // Thêm vài chu kỳ trống
    step_cycle("cycle 6");
    step_cycle("cycle 7");

    $display("== ALL CHECKS PASSED ==");
    $finish;
  end
endmodule
