//======================================================================
//
// aes_key_mem.v
// -------------
// AES-128 key memory and round key generator.
//
// AES-256 key expansion has been removed.
// Only AES-128 (128-bit key, 10 rounds) is supported.
//
//======================================================================

`default_nettype none

module aes_key_mem(
                   input wire            clk,
                   input wire            reset_n,

                   input wire [255 : 0]  key,
                   input wire            init,

                   input wire    [3 : 0] round,
                   output wire [127 : 0] round_key,
                   output wire           ready,

                   output wire [31 : 0]  sboxw,
                   input wire  [31 : 0]  new_sboxw
                  );


  //----------------------------------------------------------------
  // Parameters.
  //----------------------------------------------------------------

  // AES-128 has 10 encryption rounds plus the initial key.
  localparam AES_128_NUM_ROUNDS = 10;

  localparam CTRL_IDLE     = 3'h0;
  localparam CTRL_INIT     = 3'h1;
  localparam CTRL_GENERATE = 3'h2;
  localparam CTRL_DONE     = 3'h3;


  //----------------------------------------------------------------
  // Registers.
  //----------------------------------------------------------------

  // Only 11 round keys are required:
  // round 0 through round 10.
  reg [127 : 0] key_mem [0 : 10];

  reg [127 : 0] key_mem_new;
  reg           key_mem_we;

  // For AES-128, only one previous 128-bit key is required.
  reg [127 : 0] prev_key_reg;
  reg [127 : 0] prev_key_new;
  reg           prev_key_we;

  reg [3 : 0] round_ctr_reg;
  reg [3 : 0] round_ctr_new;
  reg         round_ctr_rst;
  reg         round_ctr_inc;
  reg         round_ctr_we;

  reg [2 : 0] key_mem_ctrl_reg;
  reg [2 : 0] key_mem_ctrl_new;
  reg         key_mem_ctrl_we;

  reg         ready_reg;
  reg         ready_new;
  reg         ready_we;

  reg [7 : 0] rcon_reg;
  reg [7 : 0] rcon_new;
  reg         rcon_we;
  reg         rcon_set;
  reg         rcon_next;


  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------

  reg [31 : 0]  tmp_sboxw;
  reg           round_key_update;
  reg [127 : 0] tmp_round_key;


  //----------------------------------------------------------------
  // Concurrent assignments for ports.
  //----------------------------------------------------------------

  assign round_key = tmp_round_key;
  assign ready     = ready_reg;
  assign sboxw     = tmp_sboxw;


  //----------------------------------------------------------------
  // reg_update
  //----------------------------------------------------------------

  always @ (posedge clk or negedge reset_n)
    begin : reg_update
      integer i;

      if (!reset_n)
        begin
          for (i = 0 ; i <= AES_128_NUM_ROUNDS ; i = i + 1)
            key_mem[i] <= 128'h0;

          ready_reg        <= 1'b1;
          rcon_reg         <= 8'h0;
          round_ctr_reg    <= 4'h0;
          prev_key_reg     <= 128'h0;
          key_mem_ctrl_reg <= CTRL_IDLE;
        end

      else
        begin
          if (ready_we)
            ready_reg <= ready_new;

          if (rcon_we)
            rcon_reg <= rcon_new;

          if (round_ctr_we)
            round_ctr_reg <= round_ctr_new;

          if (key_mem_we)
            key_mem[round_ctr_reg] <= key_mem_new;

          if (prev_key_we)
            prev_key_reg <= prev_key_new;

          if (key_mem_ctrl_we)
            key_mem_ctrl_reg <= key_mem_ctrl_new;
        end
    end


  //----------------------------------------------------------------
  // key_mem_read
  //
  // Combinational read port for the round key memory.
  //----------------------------------------------------------------

  always @*
    begin : key_mem_read
      tmp_round_key = key_mem[round];
    end


  //----------------------------------------------------------------
  // round_key_gen
  //
  // AES-128 key expansion.
  //
  // AES-128:
  //
  //   W0 W1 W2 W3  -> initial 128-bit key
  //
  // Each following round key is generated from the previous
  // 128-bit round key.
  //----------------------------------------------------------------

  always @*
    begin : round_key_gen

      reg [31 : 0] w0;
      reg [31 : 0] w1;
      reg [31 : 0] w2;
      reg [31 : 0] w3;

      reg [31 : 0] k0;
      reg [31 : 0] k1;
      reg [31 : 0] k2;
      reg [31 : 0] k3;

      reg [31 : 0] rconw;
      reg [31 : 0] rotstw;
      reg [31 : 0] trw;


      //----------------------------------------------------------------
      // Default assignments.
      //----------------------------------------------------------------

      key_mem_new   = 128'h0;
      key_mem_we    = 1'b0;

      prev_key_new  = 128'h0;
      prev_key_we   = 1'b0;

      k0 = 32'h0;
      k1 = 32'h0;
      k2 = 32'h0;
      k3 = 32'h0;

      rcon_set  = 1'b1;
      rcon_next = 1'b0;


      //----------------------------------------------------------------
      // Extract words from previous AES-128 round key.
      //----------------------------------------------------------------

      w0 = prev_key_reg[127 : 096];
      w1 = prev_key_reg[095 : 064];
      w2 = prev_key_reg[063 : 032];
      w3 = prev_key_reg[031 : 000];


      //----------------------------------------------------------------
      // Prepare the word used by the AES S-box.
      //----------------------------------------------------------------

      rconw  = {rcon_reg, 24'h0};

      // RotWord input to the shared S-box.
      tmp_sboxw = w3;

      // RotWord.
      rotstw = {
                new_sboxw[23 : 00],
                new_sboxw[31 : 24]
               };

      // SubWord + Rcon.
      trw = rotstw ^ rconw;


      //----------------------------------------------------------------
      // Generate the next AES-128 round key.
      //----------------------------------------------------------------

      if (round_key_update)
        begin
          rcon_set = 1'b0;
          key_mem_we = 1'b1;

          //------------------------------------------------------------
          // Round 0:
          //
          // Load the original 128-bit AES key.
          //
          // The existing external interface keeps key[255:128]
          // as the AES-128 key location.
          //------------------------------------------------------------

          if (round_ctr_reg == 0)
            begin
              key_mem_new  = key[255 : 128];

              prev_key_new = key[255 : 128];
              prev_key_we  = 1'b1;

              rcon_next    = 1'b1;
            end

          //------------------------------------------------------------
          // Rounds 1-10:
          //
          // Generate the next 128-bit AES round key.
          //------------------------------------------------------------

          else
            begin

              k0 = w0 ^ trw;

              k1 = w1 ^ w0 ^ trw;

              k2 = w2 ^ w1 ^ w0 ^ trw;

              k3 = w3 ^ w2 ^ w1 ^ w0 ^ trw;


              key_mem_new = {
                              k0,
                              k1,
                              k2,
                              k3
                             };

              prev_key_new = {
                               k0,
                               k1,
                               k2,
                               k3
                              };

              prev_key_we = 1'b1;

              rcon_next = 1'b1;
            end
        end
    end


  //----------------------------------------------------------------
  // rcon_logic
  //
  // Calculates the AES round constant.
  //----------------------------------------------------------------

  always @*
    begin : rcon_logic

      reg [7 : 0] tmp_rcon;

      rcon_new = 8'h00;
      rcon_we  = 1'b0;

      tmp_rcon = {
                  rcon_reg[6 : 0],
                  1'b0
                 } ^
                 (8'h1b & {8{rcon_reg[7]}});


      if (rcon_set)
        begin
          rcon_new = 8'h8d;
          rcon_we  = 1'b1;
        end


      if (rcon_next)
        begin
          rcon_new = tmp_rcon[7 : 0];
          rcon_we  = 1'b1;
        end
    end


  //----------------------------------------------------------------
  // round_ctr
  //----------------------------------------------------------------

  always @*
    begin : round_ctr

      round_ctr_new = 4'h0;
      round_ctr_we  = 1'b0;

      if (round_ctr_rst)
        begin
          round_ctr_new = 4'h0;
          round_ctr_we  = 1'b1;
        end

      else if (round_ctr_inc)
        begin
          round_ctr_new = round_ctr_reg + 1'b1;
          round_ctr_we  = 1'b1;
        end
    end


  //----------------------------------------------------------------
  // key_mem_ctrl
  //
  // FSM controlling AES-128 round key generation.
  //----------------------------------------------------------------

  always @*
    begin : key_mem_ctrl

      //----------------------------------------------------------------
      // Default assignments.
      //----------------------------------------------------------------

      ready_new        = 1'b0;
      ready_we         = 1'b0;

      round_key_update = 1'b0;

      round_ctr_rst    = 1'b0;
      round_ctr_inc    = 1'b0;

      key_mem_ctrl_new = CTRL_IDLE;
      key_mem_ctrl_we  = 1'b0;


      case (key_mem_ctrl_reg)

        //--------------------------------------------------------------
        // IDLE
        //--------------------------------------------------------------
        CTRL_IDLE:
          begin
            if (init)
              begin
                ready_new        = 1'b0;
                ready_we         = 1'b1;

                key_mem_ctrl_new = CTRL_INIT;
                key_mem_ctrl_we  = 1'b1;
              end
          end


        //--------------------------------------------------------------
        // INIT
        //--------------------------------------------------------------
        CTRL_INIT:
          begin
            round_ctr_rst    = 1'b1;

            key_mem_ctrl_new = CTRL_GENERATE;
            key_mem_ctrl_we  = 1'b1;
          end


        //--------------------------------------------------------------
        // GENERATE
        //--------------------------------------------------------------
        CTRL_GENERATE:
          begin
            round_ctr_inc    = 1'b1;
            round_key_update = 1'b1;

            if (round_ctr_reg == AES_128_NUM_ROUNDS)
              begin
                key_mem_ctrl_new = CTRL_DONE;
                key_mem_ctrl_we  = 1'b1;
              end
          end


        //--------------------------------------------------------------
        // DONE
        //--------------------------------------------------------------
        CTRL_DONE:
          begin
            ready_new        = 1'b1;
            ready_we         = 1'b1;

            key_mem_ctrl_new = CTRL_IDLE;
            key_mem_ctrl_we  = 1'b1;
          end


        //--------------------------------------------------------------
        // DEFAULT
        //--------------------------------------------------------------
        default:
          begin
            key_mem_ctrl_new = CTRL_IDLE;
            key_mem_ctrl_we  = 1'b1;
          end

      endcase
    end


endmodule


//======================================================================
// EOF aes_key_mem.v
//======================================================================