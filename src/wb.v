module wb_stage (
    input [31:0] alu_result,
    input [31:0] mem_data,
    input memtoreg,
    output [31:0] wb_data
);
    // Nếu memtoreg=1 → ghi dữ liệu từ RAM; ngược lại → từ ALU
    assign wb_data = memtoreg ? mem_data : alu_result;
endmodule