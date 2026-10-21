module present_multi_top ( 
    input         clk, 
    input         reset, 
    input         start, 
 
    input  [63:0] plaintext, 
    input  [79:0] master_key, 
 
    output [63:0] ciphertext, 
    output        done 
); 
 
    //======================================================== 
    // CONTROL SIGNALS 
    //======================================================== 
 
    wire load_enable; 
    wire initial_key_enable; 
    wire sbox_enable; 
    wire pbox_enable; 
    wire key_update_enable; 
    wire round_key_enable; 
    wire final_key_enable; 
    wire counter_enable; 
 
 
    //======================================================== 
    // ROUND COUNTER 
    //======================================================== 
 
    wire [4:0] round_counter; 
 
 
    //======================================================== 
    // CURRENT STATE / CURRENT KEY 
    //======================================================== 
 
    wire [63:0] current_state; 
    wire [79:0] current_key; 
 
    reg [63:0] next_state; 
    reg [79:0] next_key; 
 
 
    //======================================================== 
    // S-BOX / P-BOX OUTPUTS 
    //======================================================== 
 
    wire [63:0] sbox_state; 
    wire [63:0] pbox_state; 
 
 
    //======================================================== 
    // KEY SCHEDULE 
    //======================================================== 
 
    wire [79:0] generated_key; 
    wire [63:0] generated_round_key; 
 
    wire [4:0] key_round; 
 
    assign key_round = round_counter + 5'd1; 
 
 
    //======================================================== 
    // CONTROLLER 
    //======================================================== 
 
    present_controller controller ( 
 
        .clk                 (clk), 
        .reset               (reset), 
        .start               (start), 
        .round_counter       (round_counter), 
 
        .load_enable         (load_enable), 
        .initial_key_enable  (initial_key_enable), 
        .sbox_enable         (sbox_enable), 
        .pbox_enable         (pbox_enable), 
        .key_update_enable   (key_update_enable), 
        .round_key_enable    (round_key_enable), 
        .final_key_enable    (final_key_enable), 
        .counter_enable      (counter_enable), 
        .done                (done) 
    ); 
 
 
    //======================================================== 
    // STATE REGISTER 
    //======================================================== 
 
    present_state_reg state_register ( 
 
        .clk       (clk), 
        .reset     (reset), 
        .state_in  (next_state), 
        .state_out (current_state) 
    ); 
 
 
    //======================================================== 
    // KEY REGISTER 
    //======================================================== 
 
    present_key_reg key_register ( 
 
        .clk      (clk), 
        .reset    (reset), 
        .key_in   (next_key), 
        .key_out  (current_key) 
    ); 
 
 
    //======================================================== 
    // ROUND COUNTER 
    //======================================================== 
 
    present_round_counter counter ( 
 
        .clk           (clk), 
        .reset         (reset), 
        .enable        (counter_enable), 
        .round_counter (round_counter) 
    ); 
 
 
    //======================================================== 
    // 16 S-BOXES 
    //======================================================== 
 
    genvar i; 
 
    generate 
 
        for (i = 0; i < 16; i = i + 1) begin : SBOX_LAYER 
 
            present_sbox sbox ( 
 
                .sbox_in  (current_state[(i*4) +: 4]), 
                .sbox_out (sbox_state[(i*4) +: 4]) 
            ); 
 
        end 
 
    endgenerate 
 
 
    //======================================================== 
    // P-LAYER 
    //======================================================== 
 
    present_pbox pbox ( 
 
        .pbox_in  (current_state), 
        .pbox_out (pbox_state) 
    ); 
 
 
    //======================================================== 
    // KEY SCHEDULE 
    //======================================================== 
 
    present_key_schedule key_schedule ( 
 
        .key_in        (current_key), 
        .round_counter (key_round), 
        .key_out       (generated_key), 
        .round_key     (generated_round_key) 
    ); 
 
 
    //======================================================== 
    // NEXT STATE LOGIC 
    //======================================================== 
 
    always @(*) begin 
 
        next_state = current_state; 
 
 
        //==================================================== 
        // LOAD PLAINTEXT 
        //==================================================== 
 
        if (load_enable) begin 
 
            next_state = plaintext; 
 
        end 
 
 
        //==================================================== 
        // INITIAL ADD ROUND KEY 
        //==================================================== 
 
        else if (initial_key_enable) begin 
 
            next_state = 
                current_state ^ current_key[79:16]; 
 
        end 
 
 
        //==================================================== 
        // S-BOX 
        //==================================================== 
 
        else if (sbox_enable) begin 
 
            next_state = sbox_state; 
 
        end 
 
 
        //==================================================== 
        // P-LAYER 
        //==================================================== 
 
        else if (pbox_enable) begin 
 
            next_state = pbox_state; 
 
        end 
 
 
        //==================================================== 
        // NORMAL ADD ROUND KEY 
        //==================================================== 
 
        else if (round_key_enable) begin 
 
            next_state = 
                current_state ^ current_key[79:16]; 
 
        end 
 
 
        //==================================================== 
        // FINAL ADD ROUND KEY 
        //==================================================== 
 
        else if (final_key_enable) begin 
 
            next_state = 
                current_state ^ current_key[79:16]; 
 
        end 
 
    end 
 
 
    //======================================================== 
    // NEXT KEY LOGIC 
    //======================================================== 
 
    always @(*) begin 
 
        next_key = current_key; 
 
 
        //==================================================== 
        // LOAD MASTER KEY 
        //==================================================== 
 
        if (load_enable) begin 
 
            next_key = master_key; 
 
        end 
 
 
        //==================================================== 
        // UPDATE KEY 
        //==================================================== 
 
        else if (key_update_enable) begin 
 
            next_key = generated_key; 
 
        end 
 
    end 
 
 
    //======================================================== 
    // CIPHERTEXT 
    //======================================================== 
 
    assign ciphertext = current_state; 
 
endmodule