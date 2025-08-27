`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/26/2025 10:12:30 AM
// Design Name: 
// Module Name: mem_stage
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

module mem_stage (
    input clk,
    input rst,
    input [31:0] addr,
    input [31:0] write_data,
    input memread,
    input memwrite,
    output [31:0] read_data
);
    // RAM dữ liệu: 256 words (32-bit)
    reg [31:0] data_mem [0:255];
    
    // Ghi đồng bộ vào cạnh lên khi memwrite=1
    always @(posedge clk) begin
        if (memwrite) data_mem[addr[9:2]] <= write_data;
    end
    
    // Đọc kết hợp (combinational) để hỗ trợ single-cycle load trong mô phỏng
    assign read_data = memread ? data_mem[addr[9:2]] : 32'd0;
endmodule
