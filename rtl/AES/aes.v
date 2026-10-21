//======================================================================
//
// aes.v
// ------
// Top-level AES-128 encryption-only wrapper.
//
// AES-256 and decryption support have been removed.
//
//======================================================================

`default_nettype none

module aes(
           input wire          clk,
           input wire          reset_n,

           input wire          cs,
           input wire          we,
           input wire [7 : 0]  address,
           input wire [31 : 0] write_data,
           output reg [31 : 0] read_data
          );


  //----------------------------------------------------------------
  // Address definitions.
  //----------------------------------------------------------------

  localparam ADDR_CTRL    = 8'h08;
  localparam ADDR_STATUS  = 8'h09;
  localparam ADDR_CONFIG  = 8'h0a;

  localparam ADDR_KEY0    = 8'h10;
  localparam ADDR_KEY1    = 8'h11;
  localparam ADDR_KEY2    = 8'h12;
  localparam ADDR_KEY3    = 8'h13;
  localparam ADDR_KEY4    = 8'h14;
  localparam ADDR_KEY5    = 8'h15;
  localparam ADDR_KEY6    = 8'h16;
  localparam ADDR_KEY7    = 8'h17;

  localparam ADDR_BLOCK0  = 8'h20;
  localparam ADDR_BLOCK1  = 8'h21;
  localparam ADDR_BLOCK2  = 8'h22;
  localparam ADDR_BLOCK3  = 8'h23;

  localparam ADDR_RESULT0 = 8'h30;
  localparam ADDR_RESULT1 = 8'h31;
  localparam ADDR_RESULT2 = 8'h32;
  localparam ADDR_RESULT3 = 8'h33;


  //----------------------------------------------------------------
  // Control register commands.
  //----------------------------------------------------------------

  localparam CTRL_INIT = 2'b01;
  localparam CTRL_NEXT = 2'b10;


  //----------------------------------------------------------------
  // Registers.
  //----------------------------------------------------------------

  // AES-128 key.
  //
  // The key is stored in KEY0-KEY3.
  // KEY4-KEY7 are retained as unused addresses for compatibility
  // with the existing testbench.
  reg [127 : 0] key_reg;
  reg [127 : 0] key_new;
  reg           key_we;

  // Plaintext block.
  reg [127 : 0] block_reg;
  reg [127 : 0] block_new;
  reg           block_we;

  // Control signals to the AES core.
  reg           init_reg;
  reg           next_reg;


  //----------------------------------------------------------------
  // AES core connections.
  //----------------------------------------------------------------

  wire           core_ready;
  wire [127 : 0] core_result;
  wire           core_result_valid;


  //----------------------------------------------------------------
  // AES-128 encryption core.
  //----------------------------------------------------------------

  aes_core core(
                .clk(clk),
                .reset_n(reset_n),

                .init(init_reg),
                .next(next_reg),
                .ready(core_ready),

                // aes_key_mem expects the AES-128 key in
                // key[255:128].
                .key({key_reg, 128'h0}),

                .block(block_reg),
                .result(core_result),
                .result_valid(core_result_valid)
               );


  //----------------------------------------------------------------
  // Register update.
  //----------------------------------------------------------------

  always @ (posedge clk or negedge reset_n)
    begin : reg_update

      if (!reset_n)
        begin
          key_reg   <= 128'h0;
          block_reg <= 128'h0;
        end

      else
        begin
          if (key_we)
            key_reg <= key_new;

          if (block_we)
            block_reg <= block_new;
        end
    end


  //----------------------------------------------------------------
  // Write control.
  //
  // Only the AES-128 key, plaintext block and CTRL register are
  // actually used.
  //
  // CONFIG and KEY4-KEY7 are accepted as addresses but ignored.
  // This keeps compatibility with the current testbench while
  // removing the associated encryption/decryption and key-length
  // hardware.
  //----------------------------------------------------------------

  always @*
    begin : write_logic

      key_new   = key_reg;
      key_we    = 1'b0;

      block_new = block_reg;
      block_we  = 1'b0;

      init_reg  = 1'b0;
      next_reg  = 1'b0;


      if (cs && we)
        begin

          //----------------------------------------------------------
          // Control register.
          //----------------------------------------------------------
          if (address == ADDR_CTRL)
            begin
              if (write_data[0])
                init_reg = 1'b1;

              if (write_data[1])
                next_reg = 1'b1;
            end


          //----------------------------------------------------------
          // CONFIG register.
          //
          // No configuration is required anymore because this
          // design is permanently AES-128 encryption.
          //----------------------------------------------------------
          else if (address == ADDR_CONFIG)
            begin
              // Intentionally ignored.
            end


          //----------------------------------------------------------
          // AES-128 key.
          //----------------------------------------------------------
          else if (address == ADDR_KEY0)
            begin
              key_new[127 : 96] = write_data;
              key_we = 1'b1;
            end

          else if (address == ADDR_KEY1)
            begin
              key_new[95 : 64] = write_data;
              key_we = 1'b1;
            end

          else if (address == ADDR_KEY2)
            begin
              key_new[63 : 32] = write_data;
              key_we = 1'b1;
            end

          else if (address == ADDR_KEY3)
            begin
              key_new[31 : 0] = write_data;
              key_we = 1'b1;
            end


          //----------------------------------------------------------
          // KEY4-KEY7.
          //
          // These addresses are intentionally ignored because
          // AES-128 uses only 128 bits of key.
          //----------------------------------------------------------
          else if (address == ADDR_KEY4)
            begin
              // Unused.
            end

          else if (address == ADDR_KEY5)
            begin
              // Unused.
            end

          else if (address == ADDR_KEY6)
            begin
              // Unused.
            end

          else if (address == ADDR_KEY7)
            begin
              // Unused.
            end


          //----------------------------------------------------------
          // Plaintext block.
          //----------------------------------------------------------
          else if (address == ADDR_BLOCK0)
            begin
              block_new[127 : 96] = write_data;
              block_we = 1'b1;
            end

          else if (address == ADDR_BLOCK1)
            begin
              block_new[95 : 64] = write_data;
              block_we = 1'b1;
            end

          else if (address == ADDR_BLOCK2)
            begin
              block_new[63 : 32] = write_data;
              block_we = 1'b1;
            end

          else if (address == ADDR_BLOCK3)
            begin
              block_new[31 : 0] = write_data;
              block_we = 1'b1;
            end

        end
    end


  //----------------------------------------------------------------
  // Read logic.
  //----------------------------------------------------------------

  always @*
    begin : read_logic

      read_data = 32'h00000000;


      if (cs && !we)
        begin

          //----------------------------------------------------------
          // STATUS
          //
          // bit 0 = READY
          // bit 1 = RESULT VALID
          //----------------------------------------------------------
          if (address == ADDR_STATUS)
            begin
              read_data = {
                           30'h0,
                           core_result_valid,
                           core_ready
                          };
            end


          //----------------------------------------------------------
          // RESULT
          //----------------------------------------------------------
          else if (address == ADDR_RESULT0)
            begin
              read_data = core_result[127 : 96];
            end

          else if (address == ADDR_RESULT1)
            begin
              read_data = core_result[95 : 64];
            end

          else if (address == ADDR_RESULT2)
            begin
              read_data = core_result[63 : 32];
            end

          else if (address == ADDR_RESULT3)
            begin
              read_data = core_result[31 : 0];
            end


          //----------------------------------------------------------
          // KEY readback.
          //----------------------------------------------------------
          else if (address == ADDR_KEY0)
            begin
              read_data = key_reg[127 : 96];
            end

          else if (address == ADDR_KEY1)
            begin
              read_data = key_reg[95 : 64];
            end

          else if (address == ADDR_KEY2)
            begin
              read_data = key_reg[63 : 32];
            end

          else if (address == ADDR_KEY3)
            begin
              read_data = key_reg[31 : 0];
            end


          //----------------------------------------------------------
          // BLOCK readback.
          //----------------------------------------------------------
          else if (address == ADDR_BLOCK0)
            begin
              read_data = block_reg[127 : 96];
            end

          else if (address == ADDR_BLOCK1)
            begin
              read_data = block_reg[95 : 64];
            end

          else if (address == ADDR_BLOCK2)
            begin
              read_data = block_reg[63 : 32];
            end

          else if (address == ADDR_BLOCK3)
            begin
              read_data = block_reg[31 : 0];
            end

        end
    end

endmodule


//======================================================================
// EOF aes.v
//======================================================================