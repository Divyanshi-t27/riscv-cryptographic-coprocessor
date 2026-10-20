
module soc_top (
    input clk,
    input resetn,
    input mode_in,
    input [127:0] key_in,
    input [127:0] pt_in
);

    wire mem_valid;
    wire [31:0] mem_addr, mem_wdata;
    wire [3:0] mem_wstrb;

    reg mem_ready = 0;
    reg [31:0] mem_rdata = 0;

    picorv32 #(
        .PROGADDR_RESET(32'h0),
        .STACKADDR(32'h0001_0000)
    ) cpu (
        .clk(clk),
        .resetn(resetn),
        .trap(),
        .mem_valid(mem_valid),
        .mem_instr(),
        .mem_ready(mem_ready),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb),
        .mem_rdata(mem_rdata)
    );

    wire xfer = mem_valid && !mem_ready;
    wire is_wr = xfer && (|mem_wstrb);

    wire sel_ram = (mem_addr[31:16] == 16'h0000);
    wire sel_cry = (mem_addr[31:16] == 16'h4000);
    wire sel_sim = (mem_addr[31:16] == 16'h5000);

    wire [3:0] slot = mem_addr[15:12];
    wire [4:0] widx = mem_addr[6:2];

    reg [31:0] ram [0:16383];

    initial
        $readmemh("firmware.hex", ram);

    // Slot 1: Shared cryptographic co-processor
    wire [31:0] rd1;
    wire m1, s1, d1, b1;
    wire [127:0] k1, p1, c1;

    crypto_mmio mm1 (
        .clk(clk),
        .resetn(resetn),
        .wr(is_wr && sel_cry && slot == 1),
        .widx(widx),
        .wdata(mem_wdata),
        .rdata(rd1),
        .mode(m1),
        .start(s1),
        .key(k1),
        .pt(p1),
        .ct(c1),
        .core_done(d1),
        .core_busy(b1)
    );

    crypto_top u_shared (
        .clk(clk),
        .reset_n(resetn),
        .mode(m1),
        .start(s1),
        .plaintext(p1),
        .key(k1),
        .ciphertext(c1),
        .done(d1),
        .busy(b1)
    );

    always @(posedge clk) begin
        mem_ready <= 1'b0;

        if (resetn && xfer) begin
            mem_ready <= 1'b1;

            if (sel_ram) begin
                mem_rdata <= ram[mem_addr[15:2]];

                if (mem_wstrb[0])
                    ram[mem_addr[15:2]][7:0] <= mem_wdata[7:0];

                if (mem_wstrb[1])
                    ram[mem_addr[15:2]][15:8] <= mem_wdata[15:8];

                if (mem_wstrb[2])
                    ram[mem_addr[15:2]][23:16] <= mem_wdata[23:16];

                if (mem_wstrb[3])
                    ram[mem_addr[15:2]][31:24] <= mem_wdata[31:24];

            end else if (sel_cry) begin
                mem_rdata <= (slot == 1) ? rd1 : 32'h0;

            end else if (sel_sim) begin
                case (mem_addr[8:2])
                    7'h40: mem_rdata <= {31'b0, mode_in};
                    7'h44: mem_rdata <= key_in[127:96];
                    7'h45: mem_rdata <= key_in[95:64];
                    7'h46: mem_rdata <= key_in[63:32];
                    7'h47: mem_rdata <= key_in[31:0];
                    7'h48: mem_rdata <= pt_in[127:96];
                    7'h49: mem_rdata <= pt_in[95:64];
                    7'h4A: mem_rdata <= pt_in[63:32];
                    7'h4B: mem_rdata <= pt_in[31:0];
                    default: mem_rdata <= 32'h0;
                endcase

            end else begin
                mem_rdata <= 32'h0;
            end
        end
    end

    // Simulation console: writes only
    always @(posedge clk) begin
        if (is_wr && sel_sim) begin
            case (mem_addr[4:2])
                3'd0:
                    $write("%c", mem_wdata[7:0]);

                3'd1: begin
                    $display("\n[FW] finished");
                    $finish;
                end

                3'd2:
                    $display("\n[FW] KEY : %08h", mem_wdata);

                3'd3:
                    $display("[FW] PT : %08h", mem_wdata);

                3'd4:
                    $display("[FW] CT : %08h", mem_wdata);

                3'd5:
                    $display("[FW] MODE : %0d (0=AES, 1=PRESENT)",
                             mem_wdata);

                default: ;
            endcase
        end
    end

endmodule
