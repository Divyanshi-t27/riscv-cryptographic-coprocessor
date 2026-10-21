//======================================================================
//
// aes_core.v
// ----------
// AES-128 encryption-only core.
//
//======================================================================

`default_nettype none

module aes_core(
                input wire            clk,
                input wire            reset_n,

                input wire            init,
                input wire            next,
                output wire           ready,

                input wire [255 : 0]  key,

                input wire [127 : 0]  block,
                output wire [127 : 0] result,
                output wire           result_valid
               );


  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------
  localparam CTRL_IDLE = 2'h0;
  localparam CTRL_INIT = 2'h1;
  localparam CTRL_NEXT = 2'h2;


  //----------------------------------------------------------------
  // Registers including update variables and write enable.
  //----------------------------------------------------------------
  reg [1 : 0] aes_core_ctrl_reg;
  reg [1 : 0] aes_core_ctrl_new;
  reg         aes_core_ctrl_we;

  reg         result_valid_reg;
  reg         result_valid_new;
  reg         result_valid_we;

  reg         ready_reg;
  reg         ready_new;
  reg         ready_we;


  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------
  reg            init_state;

  wire [127 : 0] round_key;
  wire           key_ready;

  reg            enc_next;
  wire [3 : 0]   enc_round_nr;
  wire [127 : 0] enc_new_block;
  wire           enc_ready;
  wire [31 : 0]  enc_sboxw;

  wire [31 : 0]  keymem_sboxw;

  /* verilator lint_off UNOPTFLAT */
  reg [31 : 0]   muxed_sboxw;
  wire [31 : 0]  new_sboxw;
  /* verilator lint_on UNOPTFLAT */


  //----------------------------------------------------------------
  // Instantiations.
  //----------------------------------------------------------------
  aes_encipher_block enc_block(
                               .clk(clk),
                               .reset_n(reset_n),

                               .next(enc_next),

                               .round(enc_round_nr),
                               .round_key(round_key),

                               .sboxw(enc_sboxw),
                               .new_sboxw(new_sboxw),

                               .block(block),
                               .new_block(enc_new_block),
                               .ready(enc_ready)
                              );


  aes_key_mem keymem(
                     .clk(clk),
                     .reset_n(reset_n),

                     .key(key),
                     .init(init),

                     .round(enc_round_nr),
                     .round_key(round_key),
                     .ready(key_ready),

                     .sboxw(keymem_sboxw),
                     .new_sboxw(new_sboxw)
                    );


  aes_sbox sbox_inst(
                     .sboxw(muxed_sboxw),
                     .new_sboxw(new_sboxw)
                    );


  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------
  assign ready        = ready_reg;
  assign result       = enc_new_block;
  assign result_valid = result_valid_reg;


  //----------------------------------------------------------------
  // sbox_mux
  //
  // Controls which part of the design gets access to the shared
  // AES S-box.
  //
  // During key initialization:
  //     key memory uses the S-box.
  //
  // During encryption:
  //     encryption datapath uses the S-box.
  //----------------------------------------------------------------
  always @*
    begin : sbox_mux
      if (init_state)
        begin
          muxed_sboxw = keymem_sboxw;
        end
      else
        begin
          muxed_sboxw = enc_sboxw;
        end
    end


  //----------------------------------------------------------------
  // aes_core_ctrl
  //
  // Control FSM for the AES-128 encryption core.
  //----------------------------------------------------------------
  always @*
    begin : aes_core_ctrl
      enc_next          = 1'b0;

      init_state        = 1'b0;

      ready_new         = 1'b0;
      ready_we          = 1'b0;

      result_valid_new  = 1'b0;
      result_valid_we   = 1'b0;

      aes_core_ctrl_new = CTRL_IDLE;
      aes_core_ctrl_we  = 1'b0;


      case (aes_core_ctrl_reg)

        //------------------------------------------------------------
        // IDLE
        //------------------------------------------------------------
        CTRL_IDLE:
          begin
            if (init)
              begin
                init_state        = 1'b1;

                ready_new         = 1'b0;
                ready_we          = 1'b1;

                result_valid_new  = 1'b0;
                result_valid_we   = 1'b1;

                aes_core_ctrl_new = CTRL_INIT;
                aes_core_ctrl_we  = 1'b1;
              end

            else if (next)
              begin
                init_state        = 1'b0;

                enc_next          = 1'b1;

                ready_new         = 1'b0;
                ready_we          = 1'b1;

                result_valid_new  = 1'b0;
                result_valid_we   = 1'b1;

                aes_core_ctrl_new = CTRL_NEXT;
                aes_core_ctrl_we  = 1'b1;
              end
          end


        //------------------------------------------------------------
        // INIT
        //
        // Wait for the AES-128 key expansion to complete.
        //------------------------------------------------------------
        CTRL_INIT:
          begin
            init_state = 1'b1;

            if (key_ready)
              begin
                ready_new         = 1'b1;
                ready_we          = 1'b1;

                aes_core_ctrl_new = CTRL_IDLE;
                aes_core_ctrl_we  = 1'b1;
              end
          end


        //------------------------------------------------------------
        // NEXT
        //
        // Wait for the AES-128 encryption operation to complete.
        //------------------------------------------------------------
        CTRL_NEXT:
          begin
            init_state = 1'b0;

            if (enc_ready)
              begin
                ready_new         = 1'b1;
                ready_we          = 1'b1;

                result_valid_new  = 1'b1;
                result_valid_we   = 1'b1;

                aes_core_ctrl_new = CTRL_IDLE;
                aes_core_ctrl_we  = 1'b1;
              end
          end


        //------------------------------------------------------------
        // DEFAULT
        //------------------------------------------------------------
        default:
          begin
            aes_core_ctrl_new = CTRL_IDLE;
            aes_core_ctrl_we  = 1'b1;
          end

      endcase
    end


  //----------------------------------------------------------------
  // reg_update
  //
  // All registers are positive-edge triggered with asynchronous
  // active-low reset.
  //----------------------------------------------------------------
  always @ (posedge clk or negedge reset_n)
    begin : reg_update

      if (!reset_n)
        begin
          result_valid_reg  <= 1'b0;
          ready_reg         <= 1'b1;
          aes_core_ctrl_reg <= CTRL_IDLE;
        end

      else
        begin
          if (result_valid_we)
            result_valid_reg <= result_valid_new;

          if (ready_we)
            ready_reg <= ready_new;

          if (aes_core_ctrl_we)
            aes_core_ctrl_reg <= aes_core_ctrl_new;
        end
    end

endmodule


//======================================================================
// EOF aes_core.v
//======================================================================