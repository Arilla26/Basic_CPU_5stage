module if_stage (
    input clk,
    input rst,
    input [31:0] pc_in, // PC kế tiếp do top chọn
    output reg [31:0] pc_out, // PC hiện tại
    output [31:0] inst // Lệnh đọc ra từ bộ nhớ chương trình
);
    // Bộ nhớ chương trình: 256 lệnh (mỗi lệnh 32-bit)
    reg [31:0] instr_mem [0:255];
    
    // Nạp chương trình từ file hex (mỗi dòng 1 word 32-bit dạng hex)
    initial $readmemh("instr.mem", instr_mem);
    
    // Đọc lệnh: địa chỉ word = PC >> 2 (vì 1 lệnh = 4 byte)
    assign inst = instr_mem[pc_out[9:2]];
    
    // Cập nhật PC ở mỗi cạnh lên, reset về 0
    always @(posedge clk or posedge rst) begin
    if (rst) pc_out <= 32'd0;
    else pc_out <= pc_in;
    end
endmodule