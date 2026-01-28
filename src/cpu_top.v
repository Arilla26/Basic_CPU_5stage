`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/26/2025 09:56:04 AM
// Design Name: 
// Module Name: cpu_top
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

module cpu_top (
    input clk,
    input rst
);
    // Khai báo dây tín hiệu giữa các stage
    wire [31:0] pc; // PC hiện tại (do IF cung cấp)
    wire [31:0] inst; // Lệnh đọc từ instr_mem
    wire [31:0] rd_data1, rd_data2;// Dữ liệu đọc ra từ regfile (ID)
    wire [31:0] imm_ex; // Immediate dùng cho ALU (I/S tuỳ lệnh)
    wire [31:0] imm_b; // Immediate kiểu B (branch offset)
    wire [31:0] alu_result; // Kết quả ALU (EX)
    wire [31:0] mem_data; // Dữ liệu đọc từ data_mem (MEM)
    wire [31:0] write_data; // Dữ liệu ghi về regfile (WB)
    
    wire [4:0] rs1, rs2, rd; // Trường thanh ghi
    
    // Tín hiệu điều khiển sinh từ ID/Control
    wire regwrite; // Cho phép ghi về regfile
    wire memread; // Đọc RAM dữ liệu
    wire memwrite; // Ghi RAM dữ liệu
    wire alusrc; // Chọn toán hạng 2 của ALU: imm_ex hay rd_data2
    wire memtoreg; // Chọn dữ liệu ghi về regfile: mem_data hay alu_result
    wire branch; // Đây là lệnh nhánh B-type?
    wire [3:0] alu_ctrl; // Điều khiển phép toán ALU
    
    // ---------------- PC next logic ----------------
    // Tính PC + 4 (lệnh kế tiếp mặc định)
    wire [31:0] pc_plus4 = pc + 32'd4;
    // So sánh bằng cho BEQ (không dùng ALU, so sánh trực tiếp dữ liệu đọc ra)
    wire eq = (rd_data1 == rd_data2);
    // Tính địa chỉ nhánh: PC hiện tại + imm_b (đã căn bit 0 = 0)
    wire [31:0] branch_target = pc + imm_b;
    // Chọn PC kế tiếp: nếu là lệnh branch và điều kiện đúng → nhảy, ngược lại → PC+4
    wire [31:0] pc_next = (branch && eq) ? branch_target : pc_plus4;
    
    // ---------------- Kết nối các stage ----------------
    // IF: Lấy lệnh từ bộ nhớ chương trình
    if_stage u_if (
    .clk(clk), .rst(rst),
    .pc_in(pc_next), // PC kế tiếp từ top
    .pc_out(pc), // PC hiện tại xuất ra
    .inst(inst) // Lệnh đọc được
    );
    
    // ID: Giải mã lệnh, đọc thanh ghi, sinh điều khiển, tạo immediate
    id_stage u_id (
    .clk(clk), .rst(rst), .inst(inst), .wb_data(write_data),
    .rs1(rs1), .rs2(rs2), .rd(rd),
    .imm_ex(imm_ex), .imm_b(imm_b),
    .regwrite(regwrite), .memread(memread), .memwrite(memwrite),
    .alusrc(alusrc), .memtoreg(memtoreg), .branch(branch),
    .alu_ctrl(alu_ctrl),
    .rd_data1(rd_data1), .rd_data2(rd_data2)
    );
    
    // EX: Thực hiện phép toán (ADD/SUB/AND/OR/SLT ...)
    ex_stage u_ex (
    .rd_data1(rd_data1), .rd_data2(rd_data2), .imm_ex(imm_ex),
    .alusrc(alusrc), .alu_ctrl(alu_ctrl), .alu_result(alu_result)
    );
    
    // MEM: Truy xuất bộ nhớ dữ liệu
    mem_stage u_mem (
    .clk(clk), .rst(rst), .addr(alu_result), .write_data(rd_data2),
    .memread(memread), .memwrite(memwrite), .read_data(mem_data)
    );
    
    // WB: Chọn dữ liệu ghi về thanh ghi đích
    wb_stage u_wb (
    .alu_result(alu_result), .mem_data(mem_data), .memtoreg(memtoreg), .wb_data(write_data)
    );

endmodule

