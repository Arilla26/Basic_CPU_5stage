# Single Cycle RISC-V Processor

Một bộ vi xử lý RISC-V 32-bit (tập con RV32I) được mô tả bằng Verilog/SystemVerilog,
tổ chức theo 5 khối chức năng IF–ID–EX–MEM–WB nhưng **thực thi tuần tự một lệnh mỗi
chu kỳ clock** (single-cycle, không có thanh ghi pipeline giữa các stage).

```bash
git clone https://github.com/Arilla26/Single-Cycle-RISC-V-Processor.git
```

---

## 1. Tổng quan kiến trúc

Thiết kế tách thành 5 module theo từng giai đoạn xử lý lệnh, được nối lại trong
`cpu_top`. Vì không có pipeline register, toàn bộ đường dữ liệu từ IF đến WB hoàn tất
trong một chu kỳ; chỉ có ba phần tử trạng thái đồng bộ: thanh ghi PC, register file,
và data memory.

```
            +-------------------------------- pc_next ---------------------------------+
            |                                                                          |
            v                                                                          |
        +-------+      inst      +-------+   ctrl/imm/rd_data   +-------+  alu_result  +-------+      +-------+
clk --> |  IF   | -------------> |  ID   | -------------------> |  EX   | -----------> |  MEM  | --> |  WB   |
rst --> | (PC,  |                |(decode,|                     | (ALU) |              |(D-RAM)|     |(mux)  |
        | I-MEM)|                | regfile|                     +-------+              +-------+      +-------+
        +-------+                | control|                                                             |
            ^                    +-------+                                                              |
            |                        ^                                                                  |
            +------------ wb_data (write-back vào regfile) <-----------------------------------------+
```

Logic chọn PC kế tiếp (`pc_next`) nằm ngay trong `cpu_top`:
- Mặc định `PC + 4`.
- Với lệnh `BEQ`: nếu `rd_data1 == rd_data2` thì nhảy tới `PC + imm_b`.
  So sánh bằng được thực hiện trực tiếp tại top (`eq = rd_data1 == rd_data2`),
  **không qua ALU**, dù ID vẫn đặt `alu_ctrl = SUB` cho lệnh branch.

---

## 2. Cấu trúc file

| File | Vai trò |
|------|---------|
| `cpu_top.v` | Top-level: khai báo dây nối, logic PC-next (PC+4 / branch), instance 5 stage |
| `if.v` | IF stage: thanh ghi PC, bộ nhớ lệnh 256×32-bit nạp từ `instr.mem` |
| `id.v` | ID stage: giải mã, register file 32×32-bit, sinh control signal & immediate |
| `ex.v` | EX stage: ALU (ADD/SUB/AND/OR/SLT) và mux chọn toán hạng 2 |
| `mem.v` | MEM stage: data memory 256×32-bit (ghi đồng bộ, đọc tổ hợp) |
| `wb.v` | WB stage: mux chọn dữ liệu ghi về regfile (ALU hay RAM) |
| `instr.mem` | Chương trình mẫu dạng hex (mỗi dòng 1 word 32-bit) |
| `cpu_tb.sv` | Testbench chính: chạy chương trình addi/add/sw/lw từ `instr.mem` |
| `cpu_tb_beq.sv` | Testbench BEQ: nạp lệnh trực tiếp, kiểm tra cả TAKEN và NOT-TAKEN |

---

## 3. Tập lệnh được hỗ trợ

Thiết kế hiện cài đặt một tập con RV32I:

| Loại | Lệnh | opcode | Ghi chú |
|------|------|--------|---------|
| R-type | `ADD`, `SUB`, `AND`, `OR`, `SLT` | `0110011` | phân biệt qua `{funct7, funct3}` |
| I-type | `ADDI` | `0010011` | dùng immediate kiểu I, sign-extend |
| Load | `LW` | `0000011` | địa chỉ = `rs1 + imm_i`, ghi về `rd` |
| Store | `SW` | `0100011` | địa chỉ = `rs1 + imm_s`, ghi `rs2` xuống RAM |
| Branch | `BEQ` | `1100011` | nhảy tới `PC + imm_b` khi `rs1 == rs2` |

`SLT` so sánh có dấu (`$signed`). `NOP` được biểu diễn bằng `addi x0, x0, 0`
(opcode I-type, ghi x0 nên không có hiệu lực).

Các opcode khác rơi vào nhánh `default` của control → mọi tín hiệu điều khiển = 0
(hành xử như NOP an toàn, tránh ghi sai trạng thái).

---

## 4. Chi tiết từng stage

### 4.1. IF (`if.v`)
- `instr_mem[0:255]`, mỗi phần tử 32-bit, nạp bằng `$readmemh("instr.mem", ...)`.
- Truy cập theo word: `inst = instr_mem[pc_out[9:2]]` (PC chia 4).
- PC là thanh ghi đồng bộ, reset bất đồng bộ về 0; mỗi posedge nhận `pc_in` (chính là `pc_next`).

### 4.2. ID (`id.v`)
- **Register file** `regfile[0:31]`: đọc tổ hợp, ghi đồng bộ. `x0` được ép cứng = 0
  cả khi đọc (mux ở `rd_data1/rd_data2`) lẫn khi ghi (chặn `rd == 0`).
- **Immediate**: tạo sẵn `imm_i`, `imm_s`, `imm_b` đúng quy ước RV32I (bit dấu lấy từ `inst[31]`,
  `imm_b` đã căn bit 0 = 0).
- **Control**: khối `always @(*)` đặt giá trị mặc định cho tất cả tín hiệu ở đầu mỗi lần
  đánh giá rồi mới ghi đè theo `opcode` → **tránh latch suy luận**, một thực hành tốt.

### 4.3. EX (`ex.v`)
- Mux toán hạng 2: `op2 = alusrc ? imm_ex : rd_data2`.
- ALU tổ hợp với mã `alu_ctrl` 4-bit. `default` trả về 0.

### 4.4. MEM (`mem.v`)
- `data_mem[0:255]`, truy cập theo word `addr[9:2]`.
- Ghi **đồng bộ** tại posedge khi `memwrite=1`.
- Đọc **tổ hợp**: `read_data = memread ? data_mem[...] : 0` — cho phép `LW` hoàn tất trong cùng chu kỳ.

### 4.5. WB (`wb.v`)
- Mux thuần tổ hợp: `wb_data = memtoreg ? mem_data : alu_result`.

---

## 5. Quy ước thời gian (timing)

Đây là điểm cốt lõi cần hiểu khi đọc waveform:

1. Tại posedge thứ N, PC cập nhật thành `pc_next` của chu kỳ N−1.
2. Trong suốt chu kỳ N (sau posedge), `inst` được đọc tổ hợp, ID giải mã, EX tính ALU,
   MEM/WB cho ra `wb_data`, và `pc_next` cho chu kỳ kế tiếp được tính.
3. Tại posedge thứ N+1, regfile/data_mem ghi kết quả của lệnh chu kỳ N, **đồng thời**
   PC nhảy sang lệnh kế.

Hệ quả: kết quả của một lệnh chỉ quan sát được ở regfile/RAM **sau** posedge tiếp theo.
Các testbench đã tính đến điều này (mỗi `step` chờ 1 posedge rồi `#1` mới kiểm tra).

---

## 6. Chương trình mẫu (`instr.mem`)

```
00500093   // addi x1, x0, 5      → x1 = 5
00700113   // addi x2, x0, 7      → x2 = 7
002081B3   // add  x3, x1, x2     → x3 = 12
00302023   // sw   x3, 0(x0)      → mem[0] = 12
00002203   // lw   x4, 0(x0)      → x4 = 12
00000013   // nop (addi x0,x0,0)
```

---

## 7. Mô phỏng & kiểm chứng

Có hai testbench độc lập.

### `cpu_tb.sv` — luồng số học + bộ nhớ
Chạy chương trình trong `instr.mem` và assert lần lượt:
`x1=5`, `x2=7`, `x3=12`, `mem[0]=12`, `x4=12`. Cần đặt `instr.mem` trong Simulation Sources.

### `cpu_tb_beq.sv` — kiểm thử rẽ nhánh
Nạp lệnh trực tiếp vào `dut.u_if.instr_mem[]` (không dùng file), kiểm tra:
- **BEQ TAKEN**: `beq x1,x2,+8` với `x1==x2` → bỏ qua lệnh kế, tới đích `x3=9`.
- **BEQ NOT-TAKEN**: `beq x5,x6,+8` với `x5!=x6` → chạy tiếp `x7=11` (không nhảy).

Testbench này còn chứa các hàm `enc_addi/enc_add/enc_beq` tự mã hóa lệnh RV32I, tiện
cho việc mở rộng kịch bản kiểm thử.

### Chạy bằng các công cụ phổ biến

Vivado (xsim):
```bash
xvlog if.v id.v ex.v mem.v wb.v cpu_top.v
xvlog -sv cpu_tb.sv
xelab cpu_tb -s sim_cpu && xsim sim_cpu -R
# BEQ:
xvlog -sv cpu_tb_beq.sv
xelab cpu_tb_beq -s sim_beq && xsim sim_beq -R
```

Icarus Verilog:
```bash
iverilog -g2012 -o sim_cpu if.v id.v ex.v mem.v wb.v cpu_top.v cpu_tb.sv
vvp sim_cpu
# Dump VCD:
iverilog -g2012 -DVCD -o sim_cpu *.v cpu_tb.sv && vvp sim_cpu   # tạo cpu_tb.vcd
```

> Lưu ý: dùng `*.v` có thể kéo cả hai testbench `.sv`; nên liệt kê file tường minh
> như trên để tránh nhiều `initial`/top-module xung đột.

---

## 8. Hạn chế đã biết và hướng mở rộng

Thiết kế thiên về mục đích **giáo dục / minh họa datapath**, nên có một số giới hạn
có chủ đích. Đây không phải lỗi mà là phạm vi chưa cài đặt:

- **Single-cycle, không pipeline**: chu kỳ clock bị giới hạn bởi đường tổ hợp dài nhất
  (IF→ID→EX→MEM→WB). Để đạt tần số cao cần chèn pipeline register và xử lý hazard.
- **Tập lệnh hẹp**: chưa có `XOR/SLL/SRL/SRA/SLTU`, `JAL/JALR`, `LUI/AUIPC`,
  các nhánh `BNE/BLT/BGE/...`, hay `LB/LH/SB/SH`. ALU và bảng control có thể mở rộng tuyến tính.
- **BEQ so sánh ngoài ALU**: tín hiệu `alu_ctrl=SUB` đặt cho branch không được dùng tới;
  điều này vô hại nhưng dễ gây nhầm khi đọc code — nên ghi chú rõ hoặc thống nhất một đường.
- **Bộ nhớ không kiểm soát biên/căn chỉnh**: chỉ truy cập theo word (`addr[9:2]`),
  bỏ qua 2 bit thấp; không kiểm tra misalignment. `branch_target = pc + imm_b` không mask
  về dải địa chỉ I-MEM, an toàn với chương trình mẫu nhưng cần lưu ý khi mở rộng.
- **Load đọc tổ hợp**: tiện cho mô phỏng single-cycle nhưng không phản ánh BRAM thực
  (vốn có độ trễ đọc 1 chu kỳ). Khi đưa lên FPGA cần chuyển sang đọc đồng bộ + điều chỉnh timing.
- **Không có xử lý ngắt/ngoại lệ, không CSR.**

---

## 9. Tóm tắt nhanh

Một CPU RV32I single-cycle gọn gàng, đủ để minh họa trọn vẹn vòng đời một lệnh từ
nạp lệnh đến write-back, kèm hai testbench tự kiểm chứng cho luồng số học/bộ nhớ và
cho rẽ nhánh `BEQ`. Cấu trúc module rõ ràng, control logic tránh latch, và quy ước
register file (x0 cứng = 0) đúng chuẩn — là nền tảng tốt để mở rộng dần thành pipeline
hoặc bổ sung tập lệnh.
