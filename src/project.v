`default_nettype none

module tt_um_rule30_vga (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

  // VGA timing
  wire hsync, vsync, display_on;
  wire [9:0] hpos, vpos;

  hvsync_generator hvsync_gen (
    .clk(clk),
    .reset(~rst_n),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(display_on),
    .hpos(hpos),
    .vpos(vpos)
  );

  // Smaller Rule-30 core to fit 1x1 better: 32 cells x 20 pixels = 640 pixels
  reg  [31:0] state;
  wire [31:0] next_state;

  assign next_state = (state << 1) ^ (state | (state >> 1));

  // Update Rule-30 row at the end of each visible line
  wire new_row = display_on && (hpos == 10'd639);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= 32'b0000_0000_0000_0000_0000_0001_0000_0000;
    end else if (new_row) begin
      state <= next_state;
    end
  end

  // 32 cells across the screen -> 20 pixels per cell
  reg [4:0] cell_idx;
  reg [4:0] px_count;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cell_idx <= 5'd0;
      px_count  <= 5'd0;
    end else if (hpos == 10'd639) begin
      cell_idx <= 5'd0;
      px_count <= 5'd0;
    end else if (display_on) begin
      if (px_count == 5'd19) begin
        px_count <= 5'd0;
        cell_idx <= cell_idx + 5'd1;
      end else begin
        px_count <= px_count + 5'd1;
      end
    end
  end

  wire cell_on = display_on && state[cell_idx];
  wire [1:0] pal  = ui_in[1:0];
  wire [1:0] tone = vpos[8:7];

  reg [1:0] r_out, g_out, b_out;

  always @* begin
    r_out = 2'b00;
    g_out = 2'b00;
    b_out = 2'b00;

    if (cell_on) begin
      case (pal)
        2'b00: begin
          r_out = 2'b11;
          g_out = tone[1] ? 2'b10 : 2'b01;
          b_out = 2'b00;
        end
        2'b01: begin
          r_out = 2'b11;
          g_out = 2'b00;
          b_out = tone[0] ? 2'b11 : 2'b01;
        end
        2'b10: begin
          r_out = 2'b00;
          g_out = 2'b11;
          b_out = tone[1] ? 2'b11 : 2'b00;
        end
        default: begin
          r_out = tone[1] ? 2'b11 : 2'b01;
          g_out = tone[0] ? 2'b11 : 2'b01;
          b_out = 2'b11;
        end
      endcase
    end
  end

  // TinyTapeout VGA pin mapping
  assign uo_out[0] = r_out[1];
  assign uo_out[1] = g_out[1];
  assign uo_out[2] = b_out[1];
  assign uo_out[3] = vsync;
  assign uo_out[4] = r_out[0];
  assign uo_out[5] = g_out[0];
  assign uo_out[6] = b_out[0];
  assign uo_out[7] = hsync;

  assign uio_out = 8'b0;
  assign uio_oe  = 8'b0;

  // Consume unused inputs so the flow does not complain about floating nets
  (* keep *) wire _unused = ^{ena, uio_in, ui_in, vpos};

endmodule
