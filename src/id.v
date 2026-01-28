module id_stage (
    input clk,
    input rst,
    input [31:0] inst, // Lệnh từ IF
    input [31:0] wb_data, // Dữ liệu ghi ngược từ WB
    output [4:0] rs1, rs2, rd, // Trường thanh ghi
    output [31:0] imm_ex, // Immediate dùng cho ALU (I-imm cho addi/lw, S-imm cho sw)
    output [31:0] imm_b, // Immediate kiểu B (branch offset đã căn chỉnh)
    output reg regwrite, memread, memwrite, alusrc, memtoreg, branch, // Control signals
    output reg [3:0] alu_ctrl, // Điều khiển ALU
    output [31:0] rd_data1, rd_data2 // Dữ liệu đọc từ thanh ghi
);
    // ---------------- Regfile ----------------
    reg [31:0] regfile [0:31]; // 32 thanh ghi x0..x31
    
    // Trường cơ bản
    wire [6:0] opcode = inst[6:0];
    wire [2:0] funct3 = inst[14:12];
    wire [6:0] funct7 = inst[31:25];
    assign rs1 = inst[19:15];
    assign rs2 = inst[24:20];
    assign rd = inst[11:7];
    
    // Immediate theo từng loại
    wire [31:0] imm_i = {{20{inst[31]}}, inst[31:20]};
    wire [31:0] imm_s = {{20{inst[31]}}, inst[31:25], inst[11:7]};
    wire [31:0] imm_b_raw = {{19{inst[31]}}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0};
    assign imm_b = imm_b_raw; // đã có bit 0 = 0 (đảm bảo căn theo word)
    
    // Đọc regfile (đọc kết hợp)
    assign rd_data1 = (rs1 == 5'd0) ? 32'd0 : regfile[rs1];
    assign rd_data2 = (rs2 == 5'd0) ? 32'd0 : regfile[rs2];
    
    // Ghi regfile (ghi đồng bộ cạnh lên); không cho phép ghi x0
    integer i;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1) regfile[i] <= 32'd0;
        end else begin
            if (regwrite && (rd != 5'd0)) begin
                regfile[rd] <= wb_data;
            end
        end
    end
    
    // ---------------- Control logic ----------------
    // Mặc định: reset tất cả control về 0 để tránh latch
    reg [31:0] imm_ex_r;
    always @(*) begin
        // Defaults
        regwrite = 1'b0;
        memread = 1'b0;
        memwrite = 1'b0;
        alusrc = 1'b0;
        memtoreg = 1'b0;
        branch = 1'b0;
        alu_ctrl = 4'b0000; // mặc định ADD
        imm_ex_r = 32'd0;
    
        // Opcode mã hoá theo RV32I cơ bản
        case (opcode)
            7'b0110011: begin // R-type: add, sub, and, or, slt
                regwrite = 1'b1; // ghi về rd
                alusrc = 1'b0; // operand2 = rd_data2
                memtoreg = 1'b0; // ghi từ ALU
                // ALU control theo funct3/funct7
                case ({funct7,funct3})
                    {7'b0000000,3'b000}: alu_ctrl = 4'b0000; // ADD
                    {7'b0100000,3'b000}: alu_ctrl = 4'b0001; // SUB
                    {7'b0000000,3'b111}: alu_ctrl = 4'b0010; // AND
                    {7'b0000000,3'b110}: alu_ctrl = 4'b0011; // OR
                    {7'b0000000,3'b010}: alu_ctrl = 4'b0100; // SLT (signed)
                    default: alu_ctrl = 4'b0000; // mặc định ADD
                endcase
            end
            
            7'b0010011: begin // I-type: addi (ở đây minh hoạ addi)
                regwrite = 1'b1; // ghi về rd
                alusrc = 1'b1; // operand2 = imm_i
                memtoreg = 1'b0; // ghi từ ALU
                alu_ctrl = 4'b0000; // ADD
                imm_ex_r = imm_i; // dùng I-imm
            end
    
            7'b0000011: begin // Load: lw
                regwrite = 1'b1; // ghi về rd
                memread = 1'b1; // đọc RAM
                alusrc = 1'b1; // base + offset
                memtoreg = 1'b1; // ghi từ RAM về rd
                alu_ctrl = 4'b0000; // ADD để tính địa chỉ
                imm_ex_r = imm_i; // offset kiểu I
            end
            
            7'b0100011: begin // Store: sw
                regwrite = 1'b0; // không ghi về rd
                memwrite = 1'b1; // ghi RAM
                alusrc = 1'b1; // base + offset
                memtoreg = 1'b0; // không dùng
                alu_ctrl = 4'b0000; // ADD để tính địa chỉ
                imm_ex_r = imm_s; // offset kiểu S
            end
            
            
            7'b1100011: begin // Branch: beq (chỉ minh hoạ beq)
                regwrite = 1'b0; // không ghi rd
                branch = 1'b1; // báo là lệnh nhánh
                alusrc = 1'b0; // so sánh rd_data1 vs rd_data2
                memtoreg = 1'b0; // không dùng
                alu_ctrl = 4'b0001; // tuỳ chọn: SUB/so sánh; thực tế so eq ở top
                // imm_b đã xuất riêng
            end
        
            default: begin
                // NOP / không hỗ trợ: giữ mặc định
            end
        endcase
    end
    
    assign imm_ex = imm_ex_r; // xuất immediate đã chọn cho EX
endmodule