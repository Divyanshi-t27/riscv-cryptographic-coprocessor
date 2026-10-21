module crypto_top (
    input  wire         clk,
    input  wire         reset_n,

    // User/RISC-V control
    input  wire         mode,       // 0 = AES-128, 1 = PRESENT-80
    input  wire         start,

    // Common inputs
    input  wire [127:0] plaintext,
    input  wire [127:0] key,

    // Outputs
    output wire [127:0] ciphertext,
    output wire         done,
    output wire         busy
);

    // ============================================================
    // Controller -> Datapath control signals
    // ============================================================

    wire        load;
    wire        sub_en;
    wire [3:0]  sub_index;
    wire        sub_key_select;

    wire        shiftrows_en;
    wire        mixcolumns_en;
    wire        pbox_en;
    wire        add_round_key_en;

    wire        present_key_update_en;
    wire [4:0]  present_round;

    wire        aes_key_update_en;
    wire [7:0]  aes_sub0;
    wire [7:0]  aes_sub1;
    wire [7:0]  aes_sub2;
    wire [7:0]  aes_sub3;
    wire [7:0]  aes_rcon;

    // ============================================================
    // Datapath outputs -> Controller
    // ============================================================

    wire [127:0] state_out;
    wire [127:0] key_out;
    wire [7:0]   sub_out;

    // ============================================================
    // SHARED CONTROLLER
    // ============================================================

    crypto_shared_controller u_controller (

        .clk                    (clk),
        .reset_n                (reset_n),

        // User controls
        .mode                   (mode),
        .start                  (start),

        // Datapath feedback
        .state_out              (state_out),
        .key_out                (key_out),
        .sub_out                (sub_out),

        // Control signals
        .load                   (load),

        .sub_en                 (sub_en),
        .sub_index              (sub_index),
        .sub_key_select         (sub_key_select),

        .shiftrows_en           (shiftrows_en),
        .mixcolumns_en          (mixcolumns_en),
        .pbox_en                (pbox_en),
        .add_round_key_en       (add_round_key_en),

        .present_key_update_en  (present_key_update_en),
        .present_round          (present_round),

        .aes_key_update_en      (aes_key_update_en),
        .aes_sub0               (aes_sub0),
        .aes_sub1               (aes_sub1),
        .aes_sub2               (aes_sub2),
        .aes_sub3               (aes_sub3),
        .aes_rcon               (aes_rcon),

        .done                   (done),
        .busy                   (busy)
    );

    // ============================================================
    // SHARED DATAPATH
    // ============================================================

    crypto_shared_datapath u_datapath (

        .clk                    (clk),
        .reset_n                (reset_n),

        // User inputs
        .mode                   (mode),
        .load                   (load),
        .state_in               (plaintext),
        .key_in                 (key),

        // Shared substitution control
        .sub_en                 (sub_en),
        .sub_index              (sub_index),
        .sub_key_select         (sub_key_select),

        // AES/PRESENT transformations
        .shiftrows_en           (shiftrows_en),
        .mixcolumns_en          (mixcolumns_en),
        .pbox_en                (pbox_en),
        .add_round_key_en       (add_round_key_en),

        // PRESENT key schedule
        .present_key_update_en  (present_key_update_en),
        .present_round          (present_round),

        // AES key schedule
        .aes_key_update_en      (aes_key_update_en),
        .aes_sub0               (aes_sub0),
        .aes_sub1               (aes_sub1),
        .aes_sub2               (aes_sub2),
        .aes_sub3               (aes_sub3),
        .aes_rcon               (aes_rcon),

        // Outputs
        .state_out              (state_out),
        .key_out                (key_out),
        .sub_out                (sub_out)
    );

    // ============================================================
    // Ciphertext output
    // ============================================================

    assign ciphertext = state_out;

endmodule