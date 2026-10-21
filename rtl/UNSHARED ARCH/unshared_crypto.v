`timescale 1ns/1ps
`default_nettype none

// ============================================================================
// No-Sharing AES + PRESENT Top-Level
//
// mode = 0 : AES-128
// mode = 1 : PRESENT-80
//
// IMPORTANT:
// Both AES and PRESENT engines are instantiated unconditionally.
// The mode signal only determines which engine is activated.
//
// Therefore this represents a TRUE NO-RESOURCE-SHARING architecture.
// ============================================================================

module unshared_crypto (

    input  wire         clk,
    input  wire         reset_n,

    // Algorithm selection
    // 0 = AES-128
    // 1 = PRESENT-80
    input  wire         mode,

    // Common start signal
    input  wire         start,

    // Common input interface
    input  wire [127:0] plaintext,
    input  wire [127:0] key,

    // Common output interface
    output reg  [127:0] ciphertext,
    output reg          done,
    output reg          busy

);


    // =========================================================================
    // AES ENGINE INTERFACE
    // =========================================================================

    reg         aes_cs;
    reg         aes_we;
    reg  [7:0]  aes_address;
    reg  [31:0] aes_write_data;
    wire [31:0] aes_read_data;


    // =========================================================================
    // PRESENT ENGINE INTERFACE
    // =========================================================================

    reg         present_start;
    reg  [63:0] present_plaintext;
    reg  [79:0] present_master_key;

    wire [63:0] present_ciphertext;
    wire        present_done;


    // =========================================================================
    // AES ENGINE
    //
    // COMPLETE AES HARDWARE IS ALWAYS INSTANTIATED.
    // =========================================================================

    aes aes_engine (

        .clk        (clk),
        .reset_n    (reset_n),

        .cs         (aes_cs),
        .we         (aes_we),
        .address    (aes_address),
        .write_data (aes_write_data),
        .read_data  (aes_read_data)

    );


    // =========================================================================
    // PRESENT ENGINE
    //
    // COMPLETE PRESENT HARDWARE IS ALWAYS INSTANTIATED.
    // =========================================================================

    present_multi_top present_engine (

        .clk        (clk),
        .reset      (~reset_n),

        .start      (present_start),

        .plaintext  (present_plaintext),
        .master_key (present_master_key),

        .ciphertext (present_ciphertext),
        .done       (present_done)

    );


    // =========================================================================
    // AES REGISTER ADDRESSES
    // =========================================================================

    localparam ADDR_CTRL    = 8'h08;
    localparam ADDR_CONFIG  = 8'h0a;

    localparam ADDR_KEY0    = 8'h10;
    localparam ADDR_KEY1    = 8'h11;
    localparam ADDR_KEY2    = 8'h12;
    localparam ADDR_KEY3    = 8'h13;

    localparam ADDR_BLOCK0  = 8'h20;
    localparam ADDR_BLOCK1  = 8'h21;
    localparam ADDR_BLOCK2  = 8'h22;
    localparam ADDR_BLOCK3  = 8'h23;

    localparam ADDR_RESULT0 = 8'h30;
    localparam ADDR_RESULT1 = 8'h31;
    localparam ADDR_RESULT2 = 8'h32;
    localparam ADDR_RESULT3 = 8'h33;


    // =========================================================================
    // CONTROLLER STATES
    // =========================================================================

    localparam S_IDLE               = 5'd0;

    // -------------------------------------------------------------------------
    // AES states
    // -------------------------------------------------------------------------

    localparam S_AES_CONFIG         = 5'd1;

    localparam S_AES_KEY0           = 5'd2;
    localparam S_AES_KEY1           = 5'd3;
    localparam S_AES_KEY2           = 5'd4;
    localparam S_AES_KEY3           = 5'd5;

    localparam S_AES_BLOCK0         = 5'd6;
    localparam S_AES_BLOCK1         = 5'd7;
    localparam S_AES_BLOCK2         = 5'd8;
    localparam S_AES_BLOCK3         = 5'd9;

    localparam S_AES_INIT           = 5'd10;
    localparam S_AES_WAIT           = 5'd11;
    localparam S_AES_NEXT           = 5'd12;

    // Wait after NEXT before reading result
    localparam S_AES_POST_NEXT_WAIT = 5'd23;

    // -------------------------------------------------------------------------
    // AES result address/read states
    //
    // We use separate address and read states because aes_read_data changes
    // according to aes_address.
    // -------------------------------------------------------------------------

    localparam S_AES_RESULT0        = 5'd13;
    localparam S_AES_RESULT1        = 5'd14;
    localparam S_AES_RESULT2        = 5'd15;
    localparam S_AES_RESULT3        = 5'd16;

    localparam S_AES_RESULT0_READ   = 5'd19;
    localparam S_AES_RESULT1_READ   = 5'd20;
    localparam S_AES_RESULT2_READ   = 5'd21;
    localparam S_AES_RESULT3_READ   = 5'd22;

    // -------------------------------------------------------------------------
    // PRESENT states
    // -------------------------------------------------------------------------

    localparam S_PRESENT_RUN        = 5'd17;
    localparam S_PRESENT_WAIT       = 5'd18;


    // =========================================================================
    // STATE REGISTER
    // =========================================================================

    reg [4:0] state;


    // =========================================================================
    // ACTIVE MODE
    //
    // Capture mode when start is asserted so that changing the external mode
    // during an operation cannot change the algorithm halfway through.
    // =========================================================================

    reg active_mode;


    // =========================================================================
    // AES WAIT COUNTER
    // =========================================================================

    reg [6:0] aes_wait_count;


    // =========================================================================
    // AES RESULT REGISTER
    // =========================================================================

    reg [127:0] aes_result;


    // =========================================================================
    // CONTROLLER + OUTPUT LOGIC
    // =========================================================================

    always @(posedge clk or negedge reset_n) begin

        if (!reset_n) begin

            // -----------------------------------------------------------------
            // RESET
            // -----------------------------------------------------------------

            state              <= S_IDLE;

            active_mode        <= 1'b0;

            aes_cs             <= 1'b0;
            aes_we             <= 1'b0;
            aes_address        <= 8'h00;
            aes_write_data     <= 32'h00000000;

            present_start      <= 1'b0;
            present_plaintext  <= 64'h0000000000000000;
            present_master_key <= 80'h00000000000000000000;

            aes_wait_count     <= 7'd0;
            aes_result         <= 128'h00000000000000000000000000000000;

            ciphertext         <= 128'h00000000000000000000000000000000;
            done               <= 1'b0;
            busy               <= 1'b0;

        end

        else begin

            // -----------------------------------------------------------------
            // DEFAULT PULSE SIGNALS
            // -----------------------------------------------------------------

            aes_cs        <= 1'b0;
            aes_we        <= 1'b0;

            present_start <= 1'b0;

            done          <= 1'b0;


            // =================================================================
            // STATE MACHINE
            // =================================================================

            case (state)


                // =============================================================
                // IDLE
                // =============================================================

                S_IDLE: begin

                    busy <= 1'b0;

                    if (start) begin

                        // Capture selected algorithm
                        active_mode <= mode;

                        busy <= 1'b1;

                        if (mode == 1'b0) begin

                            // -------------------------------------------------
                            // AES selected
                            // -------------------------------------------------

                            state <= S_AES_CONFIG;

                        end

                        else begin

                            // -------------------------------------------------
                            // PRESENT selected
                            // -------------------------------------------------

                            state <= S_PRESENT_RUN;

                        end

                    end

                end


                // =============================================================
                // AES CONFIGURATION
                // =============================================================

                S_AES_CONFIG: begin

                    aes_cs         <= 1'b1;
                    aes_we         <= 1'b1;
                    aes_address    <= ADDR_CONFIG;
                    aes_write_data <= 32'h00000001;

                    state <= S_AES_KEY0;

                end


                // =============================================================
                // AES KEY 0
                // =============================================================

                S_AES_KEY0: begin

                    aes_cs         <= 1'b1;
                    aes_we         <= 1'b1;
                    aes_address    <= ADDR_KEY0;
                    aes_write_data <= key[127:96];

                    state <= S_AES_KEY1;

                end


                // =============================================================
                // AES KEY 1
                // =============================================================

                S_AES_KEY1: begin

                    aes_cs         <= 1'b1;
                    aes_we         <= 1'b1;
                    aes_address    <= ADDR_KEY1;
                    aes_write_data <= key[95:64];

                    state <= S_AES_KEY2;

                end


                // =============================================================
                // AES KEY 2
                // =============================================================

                S_AES_KEY2: begin

                    aes_cs         <= 1'b1;
                    aes_we         <= 1'b1;
                    aes_address    <= ADDR_KEY2;
                    aes_write_data <= key[63:32];

                    state <= S_AES_KEY3;

                end


                // =============================================================
                // AES KEY 3
                // =============================================================

                S_AES_KEY3: begin

                    aes_cs         <= 1'b1;
                    aes_we         <= 1'b1;
                    aes_address    <= ADDR_KEY3;
                    aes_write_data <= key[31:0];

                    state <= S_AES_BLOCK0;

                end


                // =============================================================
                // AES PLAINTEXT BLOCK 0
                // =============================================================

                S_AES_BLOCK0: begin

                    aes_cs         <= 1'b1;
                    aes_we         <= 1'b1;
                    aes_address    <= ADDR_BLOCK0;
                    aes_write_data <= plaintext[127:96];

                    state <= S_AES_BLOCK1;

                end


                // =============================================================
                // AES PLAINTEXT BLOCK 1
                // =============================================================

                S_AES_BLOCK1: begin

                    aes_cs         <= 1'b1;
                    aes_we         <= 1'b1;
                    aes_address    <= ADDR_BLOCK1;
                    aes_write_data <= plaintext[95:64];

                    state <= S_AES_BLOCK2;

                end


                // =============================================================
                // AES PLAINTEXT BLOCK 2
                // =============================================================

                S_AES_BLOCK2: begin

                    aes_cs         <= 1'b1;
                    aes_we         <= 1'b1;
                    aes_address    <= ADDR_BLOCK2;
                    aes_write_data <= plaintext[63:32];

                    state <= S_AES_BLOCK3;

                end


                // =============================================================
                // AES PLAINTEXT BLOCK 3
                // =============================================================

                S_AES_BLOCK3: begin

                    aes_cs         <= 1'b1;
                    aes_we         <= 1'b1;
                    aes_address    <= ADDR_BLOCK3;
                    aes_write_data <= plaintext[31:0];

                    state <= S_AES_INIT;

                end


                // =============================================================
                // AES INIT
                // =============================================================

                S_AES_INIT: begin

                    aes_cs         <= 1'b1;
                    aes_we         <= 1'b1;
                    aes_address    <= ADDR_CTRL;
                    aes_write_data <= 32'h00000001;

                    // Reset wait counter
                    aes_wait_count <= 7'd0;

                    state <= S_AES_WAIT;

                end


                // =============================================================
                // AES WAIT
                //
                // Wait for AES initialization/key expansion.
                // =============================================================

                S_AES_WAIT: begin

                    if (aes_wait_count == 7'd100) begin

                        aes_wait_count <= 7'd0;

                        state <= S_AES_NEXT;

                    end

                    else begin

                        aes_wait_count <= aes_wait_count + 1'b1;

                    end

                end


                // =============================================================
                // AES NEXT
                //
                // Start AES encryption.
                // =============================================================

                S_AES_NEXT: begin

                    aes_cs         <= 1'b1;
                    aes_we         <= 1'b1;
                    aes_address    <= ADDR_CTRL;
                    aes_write_data <= 32'h00000002;

                    // Start a new wait period
                    aes_wait_count <= 7'd0;

                    state <= S_AES_POST_NEXT_WAIT;

                end


                // =============================================================
                // AES POST-NEXT WAIT
                //
                // IMPORTANT:
                // AES needs time to finish encryption after NEXT.
                // Do NOT read the result immediately.
                // =============================================================

                S_AES_POST_NEXT_WAIT: begin

                    if (aes_wait_count == 7'd100) begin

                        state <= S_AES_RESULT0;

                    end

                    else begin

                        aes_wait_count <= aes_wait_count + 1'b1;

                    end

                end


                // =============================================================
                // AES RESULT 0 - SET ADDRESS
                //
                // Address is applied first.
                // Data is captured in the following state.
                // =============================================================

                S_AES_RESULT0: begin

                    aes_cs      <= 1'b1;
                    aes_we      <= 1'b0;
                    aes_address <= ADDR_RESULT0;

                    state <= S_AES_RESULT0_READ;

                end


                // =============================================================
                // AES RESULT 0 - READ
                // =============================================================

                S_AES_RESULT0_READ: begin

                    aes_cs      <= 1'b1;
                    aes_we      <= 1'b0;
                    aes_address <= ADDR_RESULT0;

                    aes_result[127:96] <= aes_read_data;

                    state <= S_AES_RESULT1;

                end


                // =============================================================
                // AES RESULT 1 - SET ADDRESS
                // =============================================================

                S_AES_RESULT1: begin

                    aes_cs      <= 1'b1;
                    aes_we      <= 1'b0;
                    aes_address <= ADDR_RESULT1;

                    state <= S_AES_RESULT1_READ;

                end


                // =============================================================
                // AES RESULT 1 - READ
                // =============================================================

                S_AES_RESULT1_READ: begin

                    aes_cs      <= 1'b1;
                    aes_we      <= 1'b0;
                    aes_address <= ADDR_RESULT1;

                    aes_result[95:64] <= aes_read_data;

                    state <= S_AES_RESULT2;

                end


                // =============================================================
                // AES RESULT 2 - SET ADDRESS
                // =============================================================

                S_AES_RESULT2: begin

                    aes_cs      <= 1'b1;
                    aes_we      <= 1'b0;
                    aes_address <= ADDR_RESULT2;

                    state <= S_AES_RESULT2_READ;

                end


                // =============================================================
                // AES RESULT 2 - READ
                // =============================================================

                S_AES_RESULT2_READ: begin

                    aes_cs      <= 1'b1;
                    aes_we      <= 1'b0;
                    aes_address <= ADDR_RESULT2;

                    aes_result[63:32] <= aes_read_data;

                    state <= S_AES_RESULT3;

                end


                // =============================================================
                // AES RESULT 3 - SET ADDRESS
                // =============================================================

                S_AES_RESULT3: begin

                    aes_cs      <= 1'b1;
                    aes_we      <= 1'b0;
                    aes_address <= ADDR_RESULT3;

                    state <= S_AES_RESULT3_READ;

                end


                // =============================================================
                // AES RESULT 3 - READ
                // =============================================================

                S_AES_RESULT3_READ: begin

                    aes_cs      <= 1'b1;
                    aes_we      <= 1'b0;
                    aes_address <= ADDR_RESULT3;

                    aes_result[31:0] <= aes_read_data;

                    // ---------------------------------------------------------
                    // Assemble complete 128-bit AES ciphertext.
                    //
                    // First three words are already stored in aes_result.
                    // The fourth word is directly available as aes_read_data.
                    // ---------------------------------------------------------

                    ciphertext <= {
                        aes_result[127:96],
                        aes_result[95:64],
                        aes_result[63:32],
                        aes_read_data
                    };

                    done <= 1'b1;
                    busy <= 1'b0;

                    state <= S_IDLE;

                end


                // =============================================================
                // PRESENT START
                // =============================================================

                S_PRESENT_RUN: begin

                    present_plaintext  <= plaintext[63:0];
                    present_master_key <= key[79:0];

                    present_start <= 1'b1;

                    state <= S_PRESENT_WAIT;

                end


                // =============================================================
                // PRESENT WAIT
                // =============================================================

                S_PRESENT_WAIT: begin

                    if (present_done) begin

                        ciphertext <= {
                            64'h0000000000000000,
                            present_ciphertext
                        };

                        done <= 1'b1;
                        busy <= 1'b0;

                        state <= S_IDLE;

                    end

                end


                // =============================================================
                // DEFAULT
                // =============================================================

                default: begin

                    state <= S_IDLE;

                    busy <= 1'b0;

                end


            endcase

        end

    end

endmodule

`default_nettype wire