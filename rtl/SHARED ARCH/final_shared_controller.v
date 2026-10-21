`timescale 1ns/1ps
`default_nettype none

module crypto_shared_controller (

    input  wire         clk,
    input  wire         reset_n,

    // 0 = AES-128
    // 1 = PRESENT-80
    input  wire         mode,
    input  wire         start,

    input  wire [127:0] state_out,
    input  wire [127:0] key_out,
    input  wire [7:0]   sub_out,

    // ------------------------------------------------------------
    // DATAPATH CONTROL
    // ------------------------------------------------------------
    output reg          load,

    output reg          sub_en,
    output reg  [3:0]   sub_index,
    output reg          sub_key_select,

    output reg          shiftrows_en,
    output reg          mixcolumns_en,
    output reg          pbox_en,
    output reg          add_round_key_en,

    // PRESENT key schedule
    output reg          present_key_update_en,
    output reg  [4:0]   present_round,

    // AES key schedule
    output reg          aes_key_update_en,
    output reg  [7:0]   aes_sub0,
    output reg  [7:0]   aes_sub1,
    output reg  [7:0]   aes_sub2,
    output reg  [7:0]   aes_sub3,
    output reg  [7:0]   aes_rcon,

    output reg          done,
    output reg          busy
);

    // ============================================================
    // FSM STATES
    // ============================================================

    localparam IDLE          = 5'd0;
    localparam LOAD          = 5'd1;
    localparam INITIAL_KEY   = 5'd2;

    // AES
    localparam AES_SBOX      = 5'd3;
    localparam AES_SHIFT     = 5'd4;
    localparam AES_MIX       = 5'd5;
    localparam AES_KEY_S0    = 5'd6;
    localparam AES_KEY_S1    = 5'd7;
    localparam AES_KEY_S2    = 5'd8;
    localparam AES_KEY_S3    = 5'd9;
    localparam AES_KEY_UPD   = 5'd10;
    localparam AES_ADD_KEY   = 5'd11;
    localparam AES_CHECK     = 5'd12;

    // PRESENT
    localparam P_SBOX        = 5'd13;
    localparam P_PBOX        = 5'd14;
    localparam P_KEY_SBOX    = 5'd15;
    localparam P_KEY_UPD     = 5'd16;
    localparam P_ADD_KEY     = 5'd17;
    localparam P_CHECK       = 5'd18;

    localparam FINISH        = 5'd19;

    reg [4:0] state_fsm;

    // ============================================================
    // COUNTERS
    // ============================================================

    reg [4:0] round_counter;
    reg [3:0] sub_counter;

    // ============================================================
    // AES KEY S-BOX RESULTS
    // ============================================================

    reg [7:0] aes_sbox0_reg;
    reg [7:0] aes_sbox1_reg;
    reg [7:0] aes_sbox2_reg;
    reg [7:0] aes_sbox3_reg;

    // ============================================================
    // AES RCON
    // ============================================================

    function [7:0] get_rcon;
        input [4:0] round;

        begin
            case (round)

                5'd1:
                    get_rcon = 8'h01;

                5'd2:
                    get_rcon = 8'h02;

                5'd3:
                    get_rcon = 8'h04;

                5'd4:
                    get_rcon = 8'h08;

                5'd5:
                    get_rcon = 8'h10;

                5'd6:
                    get_rcon = 8'h20;

                5'd7:
                    get_rcon = 8'h40;

                5'd8:
                    get_rcon = 8'h80;

                5'd9:
                    get_rcon = 8'h1b;

                5'd10:
                    get_rcon = 8'h36;

                default:
                    get_rcon = 8'h00;

            endcase
        end

    endfunction

    // ============================================================
    // COMBINATIONAL CONTROL
    // ============================================================

    always @(*) begin

        // --------------------------------------------------------
        // DEFAULTS
        // --------------------------------------------------------

        load                  = 1'b0;

        sub_en                = 1'b0;
        sub_index             = 4'd0;
        sub_key_select        = 1'b0;

        shiftrows_en          = 1'b0;
        mixcolumns_en         = 1'b0;
        pbox_en               = 1'b0;
        add_round_key_en      = 1'b0;

        present_key_update_en = 1'b0;
        present_round         = round_counter;

        aes_key_update_en     = 1'b0;

        aes_sub0              = aes_sbox0_reg;
        aes_sub1              = aes_sbox1_reg;
        aes_sub2              = aes_sbox2_reg;
        aes_sub3              = aes_sbox3_reg;

        aes_rcon              = get_rcon(round_counter);

        // --------------------------------------------------------
        // FSM CONTROL
        // --------------------------------------------------------

        case (state_fsm)

            // ====================================================
            // LOAD
            // ====================================================

            LOAD: begin

                load = 1'b1;

            end

            // ====================================================
            // INITIAL ADD ROUND KEY
            // ====================================================

            INITIAL_KEY: begin

                add_round_key_en = 1'b1;

            end

            // ====================================================
            // AES
            // ====================================================

            AES_SBOX: begin

                sub_en         = 1'b1;
                sub_index      = sub_counter;
                sub_key_select = 1'b0;

            end

            AES_SHIFT: begin

                shiftrows_en = 1'b1;

            end

            AES_MIX: begin

                mixcolumns_en = 1'b1;

            end

            // ----------------------------------------------------
            // AES KEY EXPANSION THROUGH SHARED S-BOX
            // ----------------------------------------------------

            AES_KEY_S0: begin

                sub_en         = 1'b1;
                sub_key_select = 1'b1;
                sub_index      = 4'd0;

            end

            AES_KEY_S1: begin

                sub_en         = 1'b1;
                sub_key_select = 1'b1;
                sub_index      = 4'd1;

            end

            AES_KEY_S2: begin

                sub_en         = 1'b1;
                sub_key_select = 1'b1;
                sub_index      = 4'd2;

            end

            AES_KEY_S3: begin

                sub_en         = 1'b1;
                sub_key_select = 1'b1;
                sub_index      = 4'd3;

            end

            AES_KEY_UPD: begin

                aes_key_update_en = 1'b1;

            end

            AES_ADD_KEY: begin

                add_round_key_en = 1'b1;

            end

            // ====================================================
            // PRESENT
            // ====================================================

            P_SBOX: begin

                sub_en         = 1'b1;
                sub_index      = sub_counter;
                sub_key_select = 1'b0;

            end

            P_PBOX: begin

                pbox_en = 1'b1;

            end

            // ----------------------------------------------------
            // PRESENT KEY S-BOX
            // ----------------------------------------------------

            P_KEY_SBOX: begin

                sub_en         = 1'b1;
                sub_key_select = 1'b1;
                sub_index      = 4'd0;

            end

            // ----------------------------------------------------
            // PRESENT KEY UPDATE
            //
            // IMPORTANT:
            // Keep the shared S-box connected to the PRESENT key
            // during this cycle because the datapath consumes
            // substitution_out[3:0] here.
            // ----------------------------------------------------

            P_KEY_UPD: begin

                present_key_update_en = 1'b1;

                // Keep shared S-box connected to PRESENT key
                sub_en         = 1'b1;
                sub_key_select = 1'b1;
                sub_index      = 4'd0;

                present_round  = round_counter;

            end

            P_ADD_KEY: begin

                add_round_key_en = 1'b1;

            end

            default: begin

            end

        endcase

    end

    // ============================================================
    // MAIN FSM
    // ============================================================

    always @(posedge clk or negedge reset_n) begin

        if (!reset_n) begin

            state_fsm <= IDLE;

            round_counter <= 5'd0;
            sub_counter   <= 4'd0;

            aes_sbox0_reg <= 8'h00;
            aes_sbox1_reg <= 8'h00;
            aes_sbox2_reg <= 8'h00;
            aes_sbox3_reg <= 8'h00;

            done <= 1'b0;
            busy <= 1'b0;

        end

        else begin

            done <= 1'b0;

            case (state_fsm)

                // =================================================
                // IDLE
                // =================================================

                IDLE: begin

                    busy <= 1'b0;

                    if (start) begin

                        busy          <= 1'b1;
                        round_counter <= 5'd0;
                        sub_counter   <= 4'd0;

                        state_fsm <= LOAD;

                    end

                end

                // =================================================
                // LOAD INPUTS
                // =================================================

                LOAD: begin

                    round_counter <= 5'd0;
                    sub_counter   <= 4'd0;

                    state_fsm <= INITIAL_KEY;

                end

                // =================================================
                // INITIAL ADD ROUND KEY
                //
                // AES:
                //     State = P XOR K0
                //
                // PRESENT:
                //     State = P XOR K1
                // =================================================

                INITIAL_KEY: begin

                    sub_counter <= 4'd0;

                    if (mode == 1'b0) begin

                        // AES round 1
                        round_counter <= 5'd1;
                        state_fsm <= AES_SBOX;

                    end

                    else begin

                        // PRESENT round 1
                        round_counter <= 5'd1;
                        state_fsm <= P_SBOX;

                    end

                end

                // =================================================
                // AES S-BOX
                // =================================================

                AES_SBOX: begin

                    if (sub_counter == 4'd15) begin

                        sub_counter <= 4'd0;
                        state_fsm <= AES_SHIFT;

                    end

                    else begin

                        sub_counter <= sub_counter + 4'd1;

                    end

                end

                // =================================================
                // AES SHIFT ROWS
                // =================================================

                AES_SHIFT: begin

                    if (round_counter == 5'd10)
                        state_fsm <= AES_KEY_S0;

                    else
                        state_fsm <= AES_MIX;

                end

                // =================================================
                // AES MIX COLUMNS
                // =================================================

                AES_MIX: begin

                    state_fsm <= AES_KEY_S0;

                end

                // =================================================
                // AES KEY S-BOX 0
                // =================================================

                AES_KEY_S0: begin

                    aes_sbox0_reg <= sub_out;
                    state_fsm <= AES_KEY_S1;

                end

                // =================================================
                // AES KEY S-BOX 1
                // =================================================

                AES_KEY_S1: begin

                    aes_sbox1_reg <= sub_out;
                    state_fsm <= AES_KEY_S2;

                end

                // =================================================
                // AES KEY S-BOX 2
                // =================================================

                AES_KEY_S2: begin

                    aes_sbox2_reg <= sub_out;
                    state_fsm <= AES_KEY_S3;

                end

                // =================================================
                // AES KEY S-BOX 3
                // =================================================

                AES_KEY_S3: begin

                    aes_sbox3_reg <= sub_out;
                    state_fsm <= AES_KEY_UPD;

                end

                // =================================================
                // AES KEY UPDATE
                // =================================================

                AES_KEY_UPD: begin

                    state_fsm <= AES_ADD_KEY;

                end

                // =================================================
                // AES ADD ROUND KEY
                // =================================================

                AES_ADD_KEY: begin

                    if (round_counter == 5'd10) begin

                        state_fsm <= FINISH;

                    end

                    else begin

                        round_counter <= round_counter + 5'd1;
                        sub_counter   <= 4'd0;

                        state_fsm <= AES_SBOX;

                    end

                end

                // =================================================
                // PRESENT S-BOX
                // =================================================

                P_SBOX: begin

                    if (sub_counter == 4'd15) begin

                        sub_counter <= 4'd0;
                        state_fsm <= P_PBOX;

                    end

                    else begin

                        sub_counter <= sub_counter + 4'd1;

                    end

                end

                // =================================================
                // PRESENT P-BOX
                // =================================================

                P_PBOX: begin

                    state_fsm <= P_KEY_SBOX;

                end

                // =================================================
                // PRESENT KEY S-BOX
                // =================================================

                P_KEY_SBOX: begin

                    state_fsm <= P_KEY_UPD;

                end

                // =================================================
                // PRESENT KEY UPDATE
                // =================================================

                P_KEY_UPD: begin

                    state_fsm <= P_ADD_KEY;

                end

                // =================================================
                // PRESENT ADD ROUND KEY
                // =================================================

                P_ADD_KEY: begin

                    if (round_counter == 5'd31) begin

                        // K32 has now been added
                        state_fsm <= FINISH;

                    end

                    else begin

                        round_counter <= round_counter + 5'd1;
                        sub_counter   <= 4'd0;

                        state_fsm <= P_SBOX;

                    end

                end

                // =================================================
                // FINISH
                // =================================================

                FINISH: begin

                    done <= 1'b1;
                    busy <= 1'b0;

                    state_fsm <= IDLE;

                end

                // =================================================
                // DEFAULT
                // =================================================

                default: begin

                    state_fsm <= IDLE;
                    busy <= 1'b0;

                end

            endcase

        end

    end

endmodule

`default_nettype wire