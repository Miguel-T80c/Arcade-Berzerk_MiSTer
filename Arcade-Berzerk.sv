//============================================================================
//  Arcade: Berzerk
//
//  Version for MiSTer
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [45:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different VGA_CE rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
   output [11:0] VIDEO_ARX,
   output [11:0] VIDEO_ARY,

   output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
   output [1:0]  VGA_SL,
   output        VGA_SCALER, // Force VGA scaler

	`ifdef USE_FB

   // Use framebuffer from DDRAM (USE_FB=1 in qsf)
   // FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of 16 bytes.
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
	`endif
	
   output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

   input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned

	`ifdef USE_DDRAM
	  //High latency DDR3 RAM interface
	  //Use for non-critical time purposes
	  output        DDRAM_CLK,
	  input         DDRAM_BUSY,
	  output  [7:0] DDRAM_BURSTCNT,
	  output [28:0] DDRAM_ADDR,
	  input  [63:0] DDRAM_DOUT,
	  input         DDRAM_DOUT_READY,
	  output        DDRAM_RD,
	  output [63:0] DDRAM_DIN,
	  output  [7:0] DDRAM_BE,
	  output        DDRAM_WE,
	`endif
	
	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USE_IN.
	output	USER_OSD,
	output  [1:0] USER_MODE,
	input   [7:0] USER_IN,
	output	[7:0] USER_OUT
	
);

assign VGA_F1    = 0;
assign VGA_SCALER= 0;
wire         CLK_JOY = CLK_50M;         //Assign clock between 40-50Mhz
wire   [2:0] JOY_FLAG  = {status[30],status[31],status[29]}; //Assign 3 bits of status (31:29) o (63:61)
wire         JOY_CLK, JOY_LOAD, JOY_SPLIT, JOY_MDSEL;
wire   [5:0] JOY_MDIN  = JOY_FLAG[2] ? {USER_IN[6],USER_IN[3],USER_IN[5],USER_IN[7],USER_IN[1],USER_IN[2]} : '1;
wire         JOY_DATA  = JOY_FLAG[1] ? USER_IN[5] : '1;
assign       USER_OUT  = JOY_FLAG[2] ? {3'b111,JOY_SPLIT,3'b111,JOY_MDSEL} : JOY_FLAG[1] ? {6'b111111,JOY_CLK,JOY_LOAD} : '1;
assign       USER_MODE = JOY_FLAG[2:1] ;
assign       USER_OSD  = joydb_1[10] & joydb_1[6];


assign LED_USER  = ioctl_download;
assign LED_DISK  = 0;
assign LED_POWER = 0;
//assign {FB_PAL_CLK, FB_FORCE_BLANK, FB_PAL_ADDR, FB_PAL_DOUT, FB_PAL_WR} = '0;

wire [1:0] ar = status[15:14];

assign VIDEO_ARX =  (!ar) ? ( 8'd4) : (ar - 1'd1);
assign VIDEO_ARY =  (!ar) ? ( 8'd3) : 12'd0;

`include "build_id.v" 
localparam CONF_STR = {
	"A.BERZERK;;",
	"H0OEF,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"OUV,UserIO Joystick,Off,DB9MD,DB15 ;",
	"OT,UserIO Players, 1 Player,2 Players;",
	"-;", 
	"O89,Bonus Life,None,5000,10000,5000 and 10000;",
	"OAB,Language,English,German,French,Spanish;",
	"OC,Cabinet,Upright,Cocktail;",
	"OD,Color Test,Off,On;",
	"OH,Input Test,Off,On;",
	"OI,Crosshair Pattern,Off,On;",
	"OG,Color Mode,Bright,Dark;",

	"-;",
	"R0,Reset;",
	"J1,Fire,Start 1P,Start 2P,Coin;",
	"jn,A,Start,Select,R;",
	"V,v",`BUILD_DATE
};

wire [7:0]m_dip_f2 = {status[9:8],1'b0,1'b0,1'b0,1'b0,status[13],status[13]};
wire [7:0]m_dip_f3 = {status[11:10],1'b0,1'b0,1'b0,1'b0,status[18],status[17]};
// dip_switch_1  => x"FF",  -- Coinage_B(7-4) / Cont. play(3) / Fuel consumption(2) / Fuel lost when collision (1-0)
// dip_switch_2  => x"FE",  -- Diag(7) / Demo(6) / Zippy(5) / Freeze (4) / M-Km(3) / Coin mode (2) / Cocktail(1) / Flip(0)

////////////////////   CLOCKS   ///////////////////

wire clk_sys, clk_snd;
wire pll_locked;
wire clk_40,clk_10;
assign clk_sys=clk_40;
pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_40),
	.outclk_1(clk_10),
	.locked(pll_locked)
);



///////////////////////////////////////////////////

wire [31:0] status;
wire  [1:0] buttons;
wire        forced_scandoubler;
wire        direct_video;

wire        ioctl_download;
wire        ioctl_upload;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire  [7:0] ioctl_din;
wire  [7:0] ioctl_index;
wire        ioctl_wait;

wire [10:0] ps2_key;

wire [15:0] joystick_0_USB,joystick_1_USB;
wire [15:0] joy = joystick_0 | joystick_1;

wire [21:0] gamma_bus;

// CO S2 S1 F1 U D L R 
wire [31:0] joystick_0 = joydb_1ena ? {joydb_1[11]|(joydb_1[10]&joydb_1[5]),joydb_1[9],joydb_1[10],joydb_1[4:0]} : joystick_0_USB;
wire [31:0] joystick_1 = joydb_2ena ? {joydb_2[11]|(joydb_2[10]&joydb_2[5]),joydb_2[10],joydb_2[9],joydb_2[4:0]} : joydb_1ena ? joystick_0_USB : joystick_1_USB;

wire [15:0] joydb_1 = JOY_FLAG[2] ? JOYDB9MD_1 : JOY_FLAG[1] ? JOYDB15_1 : '0;
wire [15:0] joydb_2 = JOY_FLAG[2] ? JOYDB9MD_2 : JOY_FLAG[1] ? JOYDB15_2 : '0;
wire        joydb_1ena = |JOY_FLAG[2:1]              ;
wire        joydb_2ena = |JOY_FLAG[2:1] & JOY_FLAG[0];

//----BA 9876543210
//----MS ZYXCBAUDLR
reg [15:0] JOYDB9MD_1,JOYDB9MD_2;
joy_db9md joy_db9md
(
  .clk       ( CLK_JOY    ), //40-50MHz
  .joy_split ( JOY_SPLIT  ),
  .joy_mdsel ( JOY_MDSEL  ),
  .joy_in    ( JOY_MDIN   ),
  .joystick1 ( JOYDB9MD_1 ),
  .joystick2 ( JOYDB9MD_2 )	  
);

//----BA 9876543210
//----LS FEDCBAUDLR
reg [15:0] JOYDB15_1,JOYDB15_2;
joy_db15 joy_db15
(
  .clk       ( CLK_JOY   ), //48MHz
  .JOY_CLK   ( JOY_CLK   ),
  .JOY_DATA  ( JOY_DATA  ),
  .JOY_LOAD  ( JOY_LOAD  ),
  .joystick1 ( JOYDB15_1 ),
  .joystick2 ( JOYDB15_2 )	  
);


hps_io #(.STRLEN($size(CONF_STR)>>3)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),

	.buttons(buttons),
	.status(status),
	.status_menumask(direct_video),
	.forced_scandoubler(forced_scandoubler),
	.gamma_bus(gamma_bus),
	.direct_video(direct_video),

	.ioctl_download(ioctl_download),
	.ioctl_upload(ioctl_upload),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_din(ioctl_din),
	.ioctl_index(ioctl_index),
	.ioctl_wait(ioctl_wait),

	.joystick_0(joystick_0_USB),
	.joystick_1(joystick_1_USB),
	.joy_raw(joydb_1[5:0]),
);


wire m_up     = joy[3];
wire m_down   = joy[2];
wire m_left   = joy[1];
wire m_right  = joy[0];
wire m_fire   = joy[4];

wire m_up_2     = joy[3];
wire m_down_2   = joy[2];
wire m_left_2   = joy[1];
wire m_right_2  = joy[0];
wire m_fire_2   = joy[4];

wire m_start1 = joy[5];
wire m_start2 = joy[6];
wire m_coin   = joy[7];


wire hblank, vblank;
wire hs, vs;
wire r;
wire g;
wire b;

/*
-- adapt video to 4bits/color only
video_r	<= "1100" when r = '1' and hi = '1' else
				"0100" when r = '1' and hi = '0' else
				"0000";
				
video_g	<= "1100" when g = '1' and hi = '1' else
				"0100" when g = '1' and hi = '0' else
				"0000";
				
video_b	<= "1100" when b = '1' and hi = '1' else
				"0100" when b = '1' and hi = '0' else
				"0000";
*/

// the hi wire changes the color
wire video_hi;

wire [2:0] d_video_r = { video_hi? r : 1'b0, r , 1'b0};
wire [2:0] d_video_g = { video_hi? g : 1'b0, g , 1'b0};
wire [2:0] d_video_b = { video_hi? b : 1'b0, b , 1'b0};


// brighter colors?
wire [2:0] b_video_r = { r,video_hi? r : 1'b0, r };
wire [2:0] b_video_g = { g,video_hi? g : 1'b0, g };
wire [2:0] b_video_b = { b,video_hi? b : 1'b0, b };

// select between dark and bright
wire [2:0] video_r = status[16] ? d_video_r : b_video_r;
wire [2:0] video_g = status[16] ? d_video_g : b_video_g;
wire [2:0] video_b = status[16] ? d_video_b : b_video_b;

reg ce_pix;
always @(posedge clk_40) begin
	reg [2:0] div;

	div <= div + 1'd1;
	ce_pix <= !div;
end

//wire no_rotate = status[2] | direct_video;

arcade_video #(260,9) arcade_video
(
	.*,

	.clk_video(clk_40),
	.RGB_in({video_r,video_g,video_b}),

	.HBlank(hblank),
	.VBlank(vblank),
	.HSync(hs),
	.VSync(vs),

	.fx(status[5:3])
);


wire [15:0] audio;
assign AUDIO_L =  audio;
assign AUDIO_R = AUDIO_L;
assign AUDIO_S = 0;

wire rom_download = ioctl_download && !ioctl_index;
wire [15:0] dn_addr = ioctl_addr[15:0];
 
berzerk berzerk(
	.clock_10(clk_10),
	.clk_sys(clk_sys),
	.reset(RESET | status[0] | buttons[1] | ioctl_download),

	.dn_addr(dn_addr),
	.dn_data(ioctl_dout),
	.dn_wr(ioctl_wr & rom_download),
	.dn_nvram_wr(ioctl_wr & (ioctl_index=='d4)), 
	.dn_din(ioctl_din),
	.dn_nvram(ioctl_index=='d4),

	.video_r(r),
	.video_g(g),
	.video_b(b),
	.video_hi(video_hi),
	.video_clk(),
	.video_csync(),
	.video_hs(hs),
	.video_vs(vs),
	.video_hb(hblank),
	.video_vb(vblank),
	.audio_out(audio),  
	.start2(m_start2),
	.start1(m_start1),
	.coin1(m_coin|btn_coin_2),
	.cocktail(status[12]),
	.right1(m_right),
	.left1(m_left),
	.down1(m_down),
	.up1(m_up),
	.fire1(m_fire),
	.right2(m_right_2),
	.left2(m_left_2),		
	.down2(m_down_2),
	.up2(m_up_2),
	.fire2(m_fire_2),
	.dip_f2(m_dip_f2),
	.dip_f3(m_dip_f3),
	
	.ledr(),
	//.dbg_cpu_di(),
	.dbg_cpu_addr(),
	.dbg_cpu_addr_latch()
);

endmodule
