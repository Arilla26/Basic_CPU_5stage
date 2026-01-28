module ex_stage (
    input [31:0] rd_data1,
    input [31:0] rd_data2,
    input [31:0] imm_ex,
    input alusrc,
    input [3:0] alu_ctrl,
    output reg [31:0] alu_result
);
    // Chọn toán hạng 2 cho ALU
    wire [31:0] op2 = alusrc ? imm_ex : rd_data2;
    
    // ALU cơ bản: ADD/SUB/AND/OR/SLT (signed)
    always @(*) begin
        case (alu_ctrl)
            4'b0000: alu_result = rd_data1 + op2; // ADD/ADDI/LW/SW addr
            4'b0001: alu_result = rd_data1 - op2; // SUB (R-type)
            4'b0010: alu_result = rd_data1 & op2; // AND
            4'b0011: alu_result = rd_data1 | op2; // OR
            4'b0100: alu_result = ($signed(rd_data1) < $signed(op2)) ? 32'd1 : 32'd0; // SLT
            default: alu_result = 32'd0;
        endcase
    end
endmodule