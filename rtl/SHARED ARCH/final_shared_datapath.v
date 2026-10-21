`timescale 1ns/1ps
`default_nettype none

module crypto_shared_datapath (

    input  wire         clk,
    input  wire         reset_n,

    // 0 = AES-128
    // 1 = PRESENT-80
    input  wire         mode,

    input  wire         load,

    input  wire [127:0] state_in,
    input  wire [127:0] key_in,

    // Shared S-box
    input  wire         sub_en,
    input  wire [3:0]   sub_index,

    // 0 = state through S-box
    // 1 = key through S-box
    input  wire         sub_key_select,

    // Transformations
    input  wire         shiftrows_en,
    input  wire         mixcolumns_en,
    input  wire         pbox_en,
    input  wire         add_round_key_en,

    // PRESENT key schedule
    input  wire         present_key_update_en,
    input  wire [4:0]   present_round,

    // AES key schedule
    input  wire         aes_key_update_en,
    input  wire [7:0]   aes_sub0,
    input  wire [7:0]   aes_sub1,
    input  wire [7:0]   aes_sub2,
    input  wire [7:0]   aes_sub3,
    input  wire [7:0]   aes_rcon,

    output wire [127:0] state_out,
    output wire [127:0] key_out,

    // Shared S-box output
    output wire [7:0]   sub_out

);

    // ============================================================
    // SHARED STATE REGISTER
    // ============================================================

    reg [127:0] state_reg;

    // ============================================================
    // SHARED KEY REGISTER
    // ============================================================

    reg [127:0] key_reg;

    // ============================================================
    // SHARED SUBSTITUTION UNIT
    // ============================================================

    reg  [7:0] substitution_in;
    wire [7:0] substitution_out;

    crypto_substitution substitution_unit (

        .mode     (mode),
        .data_in  (substitution_in),
        .data_out (substitution_out)

    );

    assign sub_out = substitution_out;

    // ============================================================
    // SHARED S-BOX INPUT MUX
    // ============================================================

    always @(*) begin

        substitution_in = 8'h00;

        // --------------------------------------------------------
        // KEY USING SHARED S-BOX
        // --------------------------------------------------------

        if (sub_key_select) begin

            if (mode == 1'b0) begin

                // AES RotWord:
                //
                // W3 = [09 CF 4F 3C]
                //
                // RotWord =
                // [CF 4F 3C 09]
                //
                // Therefore process:
                // key byte 13
                // key byte 14
                // key byte 15
                // key byte 12

                case (sub_index)

                    4'd0:
                        substitution_in = key_reg[23:16];

                    4'd1:
                        substitution_in = key_reg[15:8];

                    4'd2:
                        substitution_in = key_reg[7:0];

                    4'd3:
                        substitution_in = key_reg[31:24];

                    default:
                        substitution_in = 8'h00;

                endcase

            end

            else begin

                // PRESENT key S-box
                //
                // IMPORTANT:
                // old key[18:15] becomes rotated key[79:76]

                substitution_in =
                    {4'b0000, key_reg[18:15]};

            end

        end

        // --------------------------------------------------------
        // STATE USING SHARED S-BOX
        // --------------------------------------------------------

        else begin

            if (mode == 1'b0) begin

                // AES: one byte
                substitution_in =
                    state_reg[(sub_index * 8) +: 8];

            end

            else begin

                // PRESENT: one nibble
                substitution_in =
                    {4'b0000,
                     state_reg[(sub_index * 4) +: 4]};

            end

        end

    end

    // ============================================================
    // STATE REGISTER
    // ============================================================

    always @(posedge clk or negedge reset_n) begin

        if (!reset_n) begin

            state_reg <= 128'b0;

        end

        else if (load) begin

            state_reg <= state_in;

        end

        // --------------------------------------------------------
        // S-BOX RESULT WRITTEN BACK TO STATE
        // --------------------------------------------------------

        else if (sub_en && !sub_key_select) begin

            if (mode == 1'b0) begin

                state_reg[
                    (sub_index * 8) +: 8
                ] <= substitution_out;

            end

            else begin

                state_reg[
                    (sub_index * 4) +: 4
                ] <= substitution_out[3:0];

            end

        end

        // --------------------------------------------------------
        // AES SHIFT ROWS
        // --------------------------------------------------------

        else if (shiftrows_en && !mode) begin

            state_reg <= aes_shift_rows(state_reg);

        end

        // --------------------------------------------------------
        // AES MIX COLUMNS
        // --------------------------------------------------------

        else if (mixcolumns_en && !mode) begin

            state_reg <= aes_mix_columns(state_reg);

        end

        // --------------------------------------------------------
        // PRESENT P-BOX
        // --------------------------------------------------------

        else if (pbox_en && mode) begin

            state_reg[63:0] <=
                present_pbox(state_reg[63:0]);

        end

        // --------------------------------------------------------
        // ADD ROUND KEY
        // --------------------------------------------------------

        else if (add_round_key_en) begin

            if (mode == 1'b0) begin

                state_reg <=
                    state_reg ^ key_reg;

            end

            else begin

                state_reg[63:0] <=
                    state_reg[63:0] ^
                    key_reg[79:16];

            end

        end

    end

    // ============================================================
    // KEY REGISTER
    // ============================================================

    always @(posedge clk or negedge reset_n) begin

        if (!reset_n) begin

            key_reg <= 128'b0;

        end

        else if (load) begin

            key_reg <= key_in;

        end

        // --------------------------------------------------------
        // PRESENT KEY UPDATE
        // --------------------------------------------------------

        else if (present_key_update_en && mode) begin

            key_reg[79:0] <=
                present_key_schedule(

                    key_reg[79:0],

                    substitution_out[3:0],

                    present_round

                );

        end

        // --------------------------------------------------------
        // AES KEY UPDATE
        // --------------------------------------------------------

        else if (aes_key_update_en && !mode) begin

            key_reg <=
                aes_key_schedule(

                    key_reg,

                    aes_sub0,
                    aes_sub1,
                    aes_sub2,
                    aes_sub3,

                    aes_rcon

                );

        end

    end

    // ============================================================
    // AES SHIFT ROWS
    // ============================================================

    function [127:0] aes_shift_rows;

        input [127:0] s;

        begin

            aes_shift_rows[127:120] = s[127:120];
            aes_shift_rows[119:112] = s[87:80];
            aes_shift_rows[111:104] = s[47:40];
            aes_shift_rows[103:96]  = s[7:0];

            aes_shift_rows[95:88]   = s[95:88];
            aes_shift_rows[87:80]   = s[55:48];
            aes_shift_rows[79:72]   = s[15:8];
            aes_shift_rows[71:64]   = s[103:96];

            aes_shift_rows[63:56]   = s[63:56];
            aes_shift_rows[55:48]   = s[23:16];
            aes_shift_rows[47:40]   = s[111:104];
            aes_shift_rows[39:32]   = s[71:64];

            aes_shift_rows[31:24]   = s[31:24];
            aes_shift_rows[23:16]   = s[119:112];
            aes_shift_rows[15:8]    = s[79:72];
            aes_shift_rows[7:0]     = s[39:32];

        end

    endfunction

    // ============================================================
    // AES GF(2^8)
    // ============================================================

    function [7:0] aes_xtime;

        input [7:0] a;

        begin

            if (a[7])
                aes_xtime = (a << 1) ^ 8'h1b;
            else
                aes_xtime = a << 1;

        end

    endfunction

    function [7:0] aes_mul2;

        input [7:0] a;

        begin
            aes_mul2 = aes_xtime(a);
        end

    endfunction

    function [7:0] aes_mul3;

        input [7:0] a;

        begin
            aes_mul3 = aes_xtime(a) ^ a;
        end

    endfunction

    // ============================================================
    // AES MIX COLUMNS
    // ============================================================

    function [127:0] aes_mix_columns;

        input [127:0] s;

        reg [7:0] a0;
        reg [7:0] a1;
        reg [7:0] a2;
        reg [7:0] a3;

        integer c;

        begin

            aes_mix_columns = 128'b0;

            for (c = 0; c < 4; c = c + 1) begin

                a0 = s[127-(c*32) -: 8];
                a1 = s[119-(c*32) -: 8];
                a2 = s[111-(c*32) -: 8];
                a3 = s[103-(c*32) -: 8];

                aes_mix_columns[
                    127-(c*32) -: 8
                ] =
                    aes_mul2(a0) ^
                    aes_mul3(a1) ^
                    a2 ^
                    a3;

                aes_mix_columns[
                    119-(c*32) -: 8
                ] =
                    a0 ^
                    aes_mul2(a1) ^
                    aes_mul3(a2) ^
                    a3;

                aes_mix_columns[
                    111-(c*32) -: 8
                ] =
                    a0 ^
                    a1 ^
                    aes_mul2(a2) ^
                    aes_mul3(a3);

                aes_mix_columns[
                    103-(c*32) -: 8
                ] =
                    aes_mul3(a0) ^
                    a1 ^
                    a2 ^
                    aes_mul2(a3);

            end

        end

    endfunction

    // ============================================================
    // PRESENT P-BOX
    // ============================================================

    function [63:0] present_pbox;

        input [63:0] s;

        integer i;
        integer position;

        begin

            present_pbox = 64'b0;

            for (i = 0; i < 63; i = i + 1) begin

                position = (16 * i) % 63;

                present_pbox[position] = s[i];

            end

            present_pbox[63] = s[63];

        end

    endfunction

    // ============================================================
    // PRESENT-80 KEY SCHEDULE
    // ============================================================

    function [79:0] present_key_schedule;

        input [79:0] key;
        input [3:0]  sbox_value;
        input [4:0]  round_number;

        reg [79:0] rotated;

        begin

            // Rotate left by 61 bits
            rotated = {
                key[18:0],
                key[79:19]
            };

            // Shared S-box result
            rotated[79:76] = sbox_value;

            // XOR round counter
            rotated[19:15] =
                rotated[19:15] ^
                round_number;

            present_key_schedule =
                rotated;

        end

    endfunction

    // ============================================================
    // AES-128 KEY SCHEDULE
    // ============================================================

    function [127:0] aes_key_schedule;

        input [127:0] old_key;

        input [7:0] sb0;
        input [7:0] sb1;
        input [7:0] sb2;
        input [7:0] sb3;

        input [7:0] rcon;

        reg [31:0] w0;
        reg [31:0] w1;
        reg [31:0] w2;
        reg [31:0] w3;

        reg [31:0] temp;

        reg [31:0] n0;
        reg [31:0] n1;
        reg [31:0] n2;
        reg [31:0] n3;

        begin

            w0 = old_key[127:96];
            w1 = old_key[95:64];
            w2 = old_key[63:32];
            w3 = old_key[31:0];

            // SubWord(RotWord(W3))
            temp = {
                sb0,
                sb1,
                sb2,
                sb3
            };

            // Rcon applied to first byte
            temp[31:24] =
                temp[31:24] ^
                rcon;

            n0 = w0 ^ temp;
            n1 = w1 ^ n0;
            n2 = w2 ^ n1;
            n3 = w3 ^ n2;

            aes_key_schedule =
                {
                    n0,
                    n1,
                    n2,
                    n3
                };

        end

    endfunction

    // ============================================================
    // OUTPUTS
    // ============================================================

    assign state_out = state_reg;
    assign key_out   = key_reg;

endmodule

`default_nettype wire