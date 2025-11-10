class noelv_asm_program_gen extends riscv_asm_program_gen;

  `uvm_object_utils(noelv_asm_program_gen)

  function new(string name = "");
    super.new(name);
  endfunction

  // Overwriting custom extension interrupt handler section
  virtual function void gen_custom_section(ref string interrupt_handler_instr[$],
                                           privileged_mode_t mode);
    gen_timer_section(interrupt_handler_instr, mode);
    gen_plic_section(interrupt_handler_instr, mode);
  endfunction

  virtual function void gen_custom_program_header();
    gen_swar_init_section();
  endfunction

  // Only extend this function if the core utilizes a PLIC for handling interrupts
  // In this case, the core will write to a specific location as the response to the interrupt, and
  // external PLIC unit can detect this response and process the interrupt clean up accordingly.
  virtual function void gen_plic_section(ref string interrupt_handler_instr[$],
                                         privileged_mode_t mode);

    if (mode == MACHINE_MODE)
      interrupt_handler_instr.push_back($sformatf(
                                        "csrr x%0d, %0s # %0s", cfg.gpr[0], "mcause", "mcause"));
    else
      interrupt_handler_instr.push_back($sformatf(
                                        "csrr x%0d, %0s # %0s", cfg.gpr[0], "scause", "scause"));
    interrupt_handler_instr.push_back($sformatf("slli x%0d, x%0d, 1", cfg.gpr[0], cfg.gpr[0]
                                      ));  // shift out the interrupt bit
    interrupt_handler_instr.push_back($sformatf("srli x%0d, x%0d, 1", cfg.gpr[0], cfg.gpr[0]
                                      ));  // shift back
    // GPR[0] holds the interrupt value, check if 9 or 11, then perform the
    // plic claim. Keep GPR[0] to select what to claim, since this is also
    // known.
    //PLIC_BASE and PLIC_CLAIM_0 are defined in init.s in riscv-dv
    interrupt_handler_instr.push_back($sformatf("li x%0d, 11 #M ext irq", cfg.gpr[1]
                                      ));  //11 = M external interrupt
    interrupt_handler_instr.push_back($sformatf("beq x%0d, x%0d, %0s", cfg.gpr[0], cfg.gpr[1], "1f"
                                      ));
    interrupt_handler_instr.push_back($sformatf("li x%0d, 9 #S ext irq", cfg.gpr[1]
                                      ));  //9 = S external interrupt
    interrupt_handler_instr.push_back($sformatf("beq x%0d, x%0d, %0s", cfg.gpr[0], cfg.gpr[1], "2f"
                                      ));
    //plic base address
    //CLEAR S EXTERNAL INTERRUPT
    interrupt_handler_instr.push_back($sformatf("1: #M ext irq"));
    interrupt_handler_instr.push_back($sformatf("li x%0d, PLIC_BASE", cfg.gpr[0]));
    interrupt_handler_instr.push_back($sformatf("li x%0d, PLIC_CLAIM_0", cfg.gpr[1]));
    // claim register
    interrupt_handler_instr.push_back($sformatf(
                                      "add x%0d, x%0d, x%0d", cfg.gpr[2], cfg.gpr[1], cfg.gpr[0]));
    // Should we do something with the read value?
    interrupt_handler_instr.push_back($sformatf("lw x%0d, 0(x%0d)", cfg.gpr[1], cfg.gpr[2]));
    interrupt_handler_instr.push_back($sformatf("sw x%0d, 0(x%0d)", cfg.gpr[1], cfg.gpr[2]));
    // Don't run the next section
    interrupt_handler_instr.push_back($sformatf("j 3f"));

    //CLEAR S EXTERNAL INTERRUPT
    interrupt_handler_instr.push_back($sformatf("2: #S ext irq"));
    interrupt_handler_instr.push_back($sformatf("li x%0d, PLIC_BASE", cfg.gpr[0]));
    interrupt_handler_instr.push_back($sformatf("li x%0d, PLIC_CLAIM_1", cfg.gpr[1]));
    interrupt_handler_instr.push_back($sformatf(
                                      "li x%0d, START_PA #START_PHYSICAL_ADDRESS", cfg.gpr[2]));
    interrupt_handler_instr.push_back($sformatf(
                                      "add x%0d, x%0d, x%0d", cfg.gpr[1], cfg.gpr[1], cfg.gpr[0]));
    // Compensate for memory translation, PA: f820_0000 -> VA: b820_0000
    interrupt_handler_instr.push_back($sformatf(
                                      "sub x%0d, x%0d, x%0d", cfg.gpr[1], cfg.gpr[1], cfg.gpr[2]));
    interrupt_handler_instr.push_back($sformatf("lw x%0d, 0(x%0d)", cfg.gpr[0], cfg.gpr[1]));
    // write back the id to the complete the plic clean up
    interrupt_handler_instr.push_back($sformatf("sw x%0d, 0(x%0d)", cfg.gpr[0], cfg.gpr[1]));

    // END
    interrupt_handler_instr.push_back($sformatf("3:"));

    // Utilize the memory mapped handshake scheme to signal the testbench that the interrupt
    // handling has been completed and we are about to xRET out of the handler
    gen_signature_handshake(.instr(interrupt_handler_instr), .signature_type(CORE_STATUS),
                            .core_status(FINISHED_IRQ));
  endfunction

  // This function adds support for timer interrupts by confirming the
  // interrupt type and mode and then reseting the mtimer_cmp register
  virtual function void gen_timer_section(ref string interrupt_handler_instr[$],
                                          privileged_mode_t mode);
    if (mode == MACHINE_MODE)
      interrupt_handler_instr.push_back($sformatf(
                                        "csrr x%0d, %0s # %0s", cfg.gpr[0], "mcause", "mcause"));
    else
      interrupt_handler_instr.push_back($sformatf(
                                        "csrr x%0d, %0s # %0s", cfg.gpr[0], "scause", "scause"));
    interrupt_handler_instr.push_back($sformatf("slli x%0d, x%0d, 1", cfg.gpr[0], cfg.gpr[0]
                                      ));  // shift out the interrupt bit
    interrupt_handler_instr.push_back($sformatf("srli x%0d, x%0d, 1", cfg.gpr[0], cfg.gpr[0]
                                      ));  // shift back
    interrupt_handler_instr.push_back($sformatf("li x%0d, 7", cfg.gpr[1]));  //7 = mtimer interrupt
    interrupt_handler_instr.push_back($sformatf("bne x%0d, x%0d, %0s", cfg.gpr[0], cfg.gpr[1], "1f"
                                      ));
    interrupt_handler_instr.push_back($sformatf("li x%0d, MTIMER_CMP_0", cfg.gpr[1]));
    interrupt_handler_instr.push_back($sformatf("li x%0d, 0xffffffffff", cfg.gpr[0]));
    interrupt_handler_instr.push_back(
        $sformatf(
        "sw x%0d, 0(x%0d) # %0s", cfg.gpr[0], cfg.gpr[1], "set mtimecmp(31 dt 0) to max value"));
    interrupt_handler_instr.push_back(
        $sformatf(
        "sw x%0d, 4(x%0d) # %0s", cfg.gpr[0], cfg.gpr[1], "set mtimecmp(63 dt 32) to max value"));
    interrupt_handler_instr.push_back($sformatf("1:"));
  endfunction

  virtual function void gen_swar_init_section();
    string str[$];
    if (RV32NOELV inside {supported_isa} && RV32SWAR inside {supported_isa} && cfg.enable_swar_extension) begin

      // If we have stateen we need to allow all modes to access swar
      if (RV32SMSTATEEN inside {supported_isa}) begin
        // set C and stateen for lower priv mode
        str.push_back($sformatf("li x%0d, (1 << %d) | 1", cfg.gpr[0], XLEN - 1));
        str.push_back($sformatf("csrr x%0d, mstateen0", cfg.gpr[1]));
        str.push_back($sformatf("or   x%0d, x%0d, x%0d", cfg.gpr[0], cfg.gpr[1], cfg.gpr[0]));
        str.push_back($sformatf("csrw mstateen0, x%0d", cfg.gpr[0]));
        str.push_back($sformatf("csrr x%0d, mstateen0", cfg.gpr[0]));
        if (RV32SSTATEEN inside {supported_isa}) begin
          if (RV32H inside {supported_isa} && cfg.enable_h_extension) begin
            str.push_back($sformatf("li   x%0d, (1 << %d) | 1", cfg.gpr[0], XLEN - 1));
            str.push_back($sformatf("csrr x%0d, hstateen0", cfg.gpr[1]));
            str.push_back($sformatf("or   x%0d, x%0d, x%0d", cfg.gpr[0], cfg.gpr[1], cfg.gpr[0]));
            str.push_back($sformatf("csrw hstateen0, x%0d", cfg.gpr[0]));
            str.push_back($sformatf("csrr x%0d, hstateen0", cfg.gpr[0]));
          end
          if (SUPERVISOR_MODE inside {supported_privileged_mode}) begin
            str.push_back($sformatf("li x%0d, 1", cfg.gpr[0]));
            str.push_back($sformatf("csrr x%0d, sstateen0", cfg.gpr[1]));
            str.push_back($sformatf("or   x%0d, x%0d, x%0d", cfg.gpr[0], cfg.gpr[1], cfg.gpr[0]));
            str.push_back($sformatf("csrw sstateen0, x%0d", cfg.gpr[0]));
            str.push_back($sformatf("csrr x%0d, sstateen0", cfg.gpr[0]));
            str.push_back($sformatf("\n"));
          end
        end
      end
      gen_section("custom_init", str);
    end
  endfunction


  typedef struct packed {
    bit dual_dis;     // Disable dual-issue
    bit bprd_dis;     // Disable branch prediction
    bit jprd_dis;     // Disable BTB
    bit ras_dis;      // Disable RAS
    bit lbranch_dis;  // Disable late branch prediction
    bit lalu_dis;     // Disable late ALU
    bit b2bst_dis;    // Disable back-to-back stores (any size)
    bit mmu_adfault;  // Set AD bits (better to support SVADU properly first)
    bit staticbp;     // Enable static branch prrediction
    bit staticdir;    // Static branch prediction config
    bit nostream;     // Disable instruction streaming
  } csr_features_t;

  rand csr_features_t r_feature;

  constraint ad_fault_c {
    r_feature.mmu_adfault == 1;  // Not quite supported in cosim
  }

  virtual function void init_custom_csr(ref string instr[$]);
    if (!this.randomize()) begin
      `uvm_fatal("RAND_FAIL", "Randomization failed for r_feature")
    end
    if (RV32NOELV inside {supported_isa}) begin
      `uvm_info(`gfn, $sformatf("Randomizing CSR features: %x", r_feature), UVM_LOW)
      instr.push_back({
                      indent,
                      $sformatf(
                          "li x%0d, 0x%0x | %d << 63",
                          cfg.gpr[0],
                          r_feature,
                          cfg.enable_swar_extension
                      )
                      });
      instr.push_back({indent, $sformatf("csrw 0x%0x, x%0d #nvc_features", 12'h7c0, cfg.gpr[0])});
    end
  endfunction

endclass

class csr_features_instr_stream extends riscv_directed_instr_stream;
  typedef struct packed {
    bit dual_dis;     // Disable dual-issue
    bit bprd_dis;     // Disable branch prediction
    bit jprd_dis;     // Disable BTB
    bit ras_dis;      // Disable RAS
    bit lbranch_dis;  // Disable late branch prediction
    bit lalu_dis;     // Disable late ALU
    bit b2bst_dis;    // Disable back-to-back stores (any size)
    bit mmu_adfault;  // Set AD bits (better to support SVADU properly first)
    bit staticbp;     // Enable static branch prrediction
    bit staticdir;    // Static branch prediction config
    bit nostream;     // Disable instruction streaming
  } csr_features_t;

  rand csr_features_t r_feature;

  constraint ad_fault_c {
    r_feature.mmu_adfault == 1;  // Not quite supported in cosim
  }
  riscv_instr tmp_instr;
  int unsigned num_of_avail_regs = 1;
  int tmp_imm;

  `uvm_object_utils(csr_features_instr_stream)
  `uvm_object_new

  constraint avail_regs_c {
    unique {avail_regs};
    foreach (avail_regs[i]) {
      !(avail_regs[i] inside {cfg.reserved_regs});
      avail_regs[i] != ZERO;
    }
  }

  function void pre_randomize();
    avail_regs = new[num_of_avail_regs];
    super.pre_randomize();
  endfunction : pre_randomize

  function void post_randomize();
    if (RV32NOELV inside {supported_isa} && cfg.init_privileged_mode == MACHINE_MODE) begin
      riscv_pseudo_instr li_instr;
      li_instr = new();
      randomize_gpr(li_instr);
      li_instr.pseudo_instr_name = LI;
      li_instr.imm_str = $sformatf("0x%8h | %d << 63", r_feature,
                                   cfg.enable_swar_extension);  // For the sake of SWAR
      instr_list.push_back(li_instr);

      //read/write fssr
      tmp_instr = riscv_instr::get_instr(CSRRW);
      tmp_instr.csr = 12'h7c0;
      tmp_instr.rs1 = li_instr.rd;
      tmp_instr.rd = li_instr.rd;
      instr_list.push_back(tmp_instr);
      super.post_randomize();
    end

  endfunction

endclass

class riscv_swar_instr extends riscv_instr;
  `uvm_object_utils(riscv_swar_instr)

  function new(string name = "");
    super.new(name);
  endfunction : new

  // Only a single instruction
  virtual function void set_rand_mode();
    super.set_rand_mode();
    has_rd  = 1'b1;
    has_rs2 = 1'b1;
    has_rs1 = 1'b1;
    has_imm = 1'b0;
    format  = R_FORMAT;
  endfunction

  function void pre_randomize();
    super.pre_randomize();
  endfunction

  virtual function bit is_supported(riscv_instr_gen_config cfg);
    return (cfg.enable_swar_extension && (RV32SWAR inside {supported_isa}));
  endfunction : is_supported

  virtual function bit [6:0] get_func7();
    case (instr_name) inside
      SWAR: get_func7 = 7'b0000000;
      default: get_func7 = super.get_func7();
    endcase
  endfunction

  virtual function bit [2:0] get_func3();
    case (instr_name) inside
      SWAR: get_func3 = 3'b000;
      default: get_func3 = super.get_func3();
    endcase
  endfunction

  function bit [6:0] get_opcode();
    case (instr_name) inside
      SWAR   : get_opcode = 7'b0101011;
      default : get_opcode = super.get_opcode();
    endcase
  endfunction : get_opcode

  virtual function string convert2bin(string prefix = "");
    return {prefix, $sformatf("0x%8h", {get_func7(), rs2, rs1, get_func3(), rd, get_opcode()})};
  endfunction : convert2bin

  virtual function string convert2asm(string prefix = "");
    string asm_str = format_string("swar", MAX_INSTR_STR_LEN);
    // string asm_str = {convert2bin(".4byte "), comment};
    asm_str = $sformatf("%0s%s, %s, %s", asm_str, rd.name(), rs1.name(), rs2.name());
    return asm_str.tolower();
  endfunction

endclass

class swar_instr_stream extends riscv_directed_instr_stream;

  typedef enum bit [7:0] {
    COR1b   = 8'b00000100,
    COR2b   = 8'b00000101,
    COR3b   = 8'b00000110,
    COR4b   = 8'b00000111,
    DEMR2b  = 8'b00001001,
    DEMR3b  = 8'b00001010,
    DEMR4b  = 8'b00001011,
    DEMC2b  = 8'b00001101,
    DEMC3b  = 8'b00001110,
    DEMC4b  = 8'b00001111,
    DEMC2bG = 8'b00000001,
    DEMC3bG = 8'b00000010,
    DEMC4bG = 8'b00000011,
    SC1b    = 8'b00010000,
    SC2b    = 8'b00100000,
    SC3b    = 8'b00110000,
    SC4b    = 8'b01000000,
    SWADD   = 8'b00000000,
    SWSUB   = 8'b00001000,
    SWMUL   = 8'b00001100,
    SWSHR   = 8'b10000000
  } swar_opcode_t;

  typedef struct {
    rand swar_opcode_t select;  // 0:7
    rand bit sign;  // 8
    rand bit red;  // 9
    rand bit sat;  // 10
    rand bit norm;  // 11
    rand bit audio;  // 12
    rand bit video;  // 13
    rand bit alu;  // 14
    bit res0 = 0;  // 15
    rand bit [5:0] dyn_rng;  // 16:22
    rand bit restr;  // 23
    rand bit refblk;  // 24
    rand bit ctrl_clear;  // 25
  } swar_csr_t;

  // --- Feature flags for cfg 0 ---
  bit supports_swcorrel = 1;
  bit supports_swdemod  = 1;
  bit supports_swsincos = 1;
  bit supports_swaudio  = 1;
  bit supports_swvideo  = 1;
  bit supports_swalu    = 1;
  bit supports_swksplit = 0;
  bit supports_swacc    = 1;
  bit supports_swaccseq = 0;
  int swidth   = 5;
  int swlanes  = 16;
  int swawidth = 64;

  bit[11:0] CSR_SWAR_CTRLSTAT = 12'h801;
  bit[11:0] CSR_SWAR_ACC_SEL = 12'h802;
  bit[11:0] CSR_SWAR_ACC_VAL = 12'h803;

  swar_opcode_t supported_opcodes[$];

  typedef enum int {
    ACCUMULATE_WRITE,
    ACCUMULATE_READ,
    ACCUMULATE_SELECT,
    CALC
  } swar_op_t;

  rand int unsigned       r_num_of_ops;
  rand swar_op_t          r_ops_q          [$];
  rand bit                r_op_swar_other_q[$];
  rand bit          [4:0] r_acc_sel;
  rand swar_csr_t         r_swar_q         [$];
  rand int unsigned       r_reconfig_ratio;

  function void pre_randomize();
    super.pre_randomize();
    `DV_CHECK_STD_RANDOMIZE_FATAL(r_num_of_ops);
    `DV_CHECK_STD_RANDOMIZE_FATAL(r_reconfig_ratio);
  endfunction : pre_randomize


  constraint r_num_of_ops_c {r_num_of_ops inside {[100 : 1000]};}

  constraint r_reconfig_ratio_c {r_reconfig_ratio inside {[0 : 100]};}

  // Register instruction stream with uvm factory
  `uvm_object_utils(swar_instr_stream)

  function new(string name = "swar_instr_stream");
    super.new(name);
    pre_randomize();
    randomize_avail_regs();
    `uvm_info(`gfn, $sformatf("Creating swar instruction stream"), UVM_LOW)

    // This logic now correctly populates the queue when the object is created.
    if (supports_swcorrel) begin
      supported_opcodes.push_back(COR1b);
      supported_opcodes.push_back(COR2b);
      supported_opcodes.push_back(COR3b);
      supported_opcodes.push_back(COR4b);
      `uvm_info(`gfn, $sformatf("SWAR: Adding correlation operations"), UVM_LOW)
    end
    if (supports_swdemod) begin
      supported_opcodes.push_back(DEMR2b);
      supported_opcodes.push_back(DEMR3b);
      supported_opcodes.push_back(DEMR4b);
      supported_opcodes.push_back(DEMC2b);
      supported_opcodes.push_back(DEMC3b);
      supported_opcodes.push_back(DEMC4b);
      supported_opcodes.push_back(DEMC2bG);
      supported_opcodes.push_back(DEMC3bG);
      supported_opcodes.push_back(DEMC4bG);
      `uvm_info(`gfn, $sformatf("SWAR: Adding demodulation operations"), UVM_LOW)
    end
    if (supports_swsincos) begin
      supported_opcodes.push_back(SC1b);
      supported_opcodes.push_back(SC2b);
      supported_opcodes.push_back(SC3b);
      supported_opcodes.push_back(SC4b);
      `uvm_info(`gfn, $sformatf("SWAR: Adding sincos operations"), UVM_LOW)
    end
    if (supports_swvideo || supports_swaudio || supports_swalu) begin
      supported_opcodes.push_back(SWADD);
      supported_opcodes.push_back(SWSUB);
      supported_opcodes.push_back(SWMUL);
      supported_opcodes.push_back(SWSHR);
      `uvm_info(`gfn, $sformatf("SWAR: Adding ALU operations"), UVM_LOW)
    end
  endfunction

  constraint opcode_c {
    // r_num_of_ops is technically more than we need, easier however to do it
    // this way...
    r_swar_q.size() == r_num_of_ops;
    foreach (r_swar_q[i]) {r_swar_q[i].select inside {supported_opcodes};}
  }

  constraint ops_q_c {
    r_ops_q.size() == r_num_of_ops;

    if (supports_swacc) {
      foreach (r_ops_q[i]) {
        r_ops_q[i] dist {
          ACCUMULATE_WRITE  := 3,
          ACCUMULATE_READ   := 6,
          ACCUMULATE_SELECT := 3,
          CALC              := 90
        };
      }
    } else {
      foreach (r_ops_q[i]) {
        !(r_ops_q[i] inside {ACCUMULATE_SELECT, ACCUMULATE_READ, ACCUMULATE_WRITE});
      }
    }
  }

  constraint r_op_swar_other_q_c {
    r_op_swar_other_q.size() == r_num_of_ops;
    foreach (r_op_swar_other_q[i]) {
      r_op_swar_other_q[i] dist {
        0 := 64,  // Slightly prefer other ops
        1 := 40
      };
    }
  }

  constraint alu_ctrl_c {
    r_swar_q.size() == r_num_of_ops;
    foreach (r_swar_q[i]) {
      solve r_swar_q[i].select before r_swar_q[i].alu;
      if (!supports_swalu) {r_swar_q[i].alu == 0;}
    }
  }

  // Define the relationship between the opcode and the feature bits.
  constraint features_c {
    r_swar_q.size() == r_num_of_ops;
    foreach (r_swar_q[i]) {
      solve r_swar_q[i].select before r_swar_q[i].audio, r_swar_q[i].video, r_swar_q[i].alu;

      (r_swar_q[i].select inside {SWADD, SWSUB, SWMUL, SWSHR}) ->
      // one of the audio/video/alu flags must be set.
      {
        (r_swar_q[i].audio + r_swar_q[i].video + r_swar_q[i].alu) == 1;
      }
    }
  }

  function bit [31:0] pack_swar_csr_t(swar_csr_t in);
    bit [31:0] ret = '0;
    ret[7:0]   = in.select;
    ret[8]     = in.sign;
    ret[9]     = in.red;
    ret[10]    = in.sat;
    ret[11]    = in.norm;
    ret[12]    = in.audio;
    ret[13]    = in.video;
    ret[14]    = in.alu;
    ret[15]    = in.res0;
    ret[21:16] = in.dyn_rng;
    ret[22]    = in.restr;
    ret[23]    = in.refblk;
    ret[24]    = in.ctrl_clear;
    return ret;
  endfunction

  function void reconfigure_ctrl(int idx);
    riscv_instr tmp_instr;
    riscv_pseudo_instr li_instr;
    tmp_instr = new();
    li_instr  = new();

    randomize_gpr(li_instr);
    li_instr.pseudo_instr_name = LI;
    li_instr.imm_str = $sformatf("0x%8h # Reconfigure swar ctrl", pack_swar_csr_t(r_swar_q[idx]));
    instr_list.push_back(li_instr);

    tmp_instr = riscv_instr::get_instr(CSRRW);
    tmp_instr.comment = $sformatf(
        "SWAR CTRL RECONF: op: %s  sign %d red %d sat %d norm %d audio %d video %d alu %d res0 %d dyn_rng %d restr %d refblk %d clear %d",
        r_swar_q[idx].select.name,
        r_swar_q[idx].sign,
        r_swar_q[idx].red,
        r_swar_q[idx].sat,
        r_swar_q[idx].norm,
        r_swar_q[idx].audio,
        r_swar_q[idx].video,
        r_swar_q[idx].alu,
        r_swar_q[idx].res0,
        r_swar_q[idx].dyn_rng,
        r_swar_q[idx].restr,
        r_swar_q[idx].refblk,
        r_swar_q[idx].ctrl_clear
    );
    if (r_swar_q[idx].res0 == 1) begin
      `uvm_fatal("SWAR:", "res0 can't be 1");
    end

    if (r_swar_q[idx].alu == 1 && !supports_swalu) begin
      `uvm_fatal("SWAR:", "Constraint for swalu not fulfilled");
    end

    if (r_swar_q[idx].select inside {SWSHR, SWADD, SWSUB, SWMUL} &&
      (r_swar_q[idx].alu + r_swar_q[idx].video + r_swar_q[idx].audio != 1)) begin
      `uvm_fatal("SWAR", $sformatf(
                 "Constraint not fulfilled alu %01d video %01d audio %01d",
                 r_swar_q[idx].alu,
                 r_swar_q[idx].video,
                 r_swar_q[idx].audio
                 ));
    end

    tmp_instr.rs1 = li_instr.rd;
    tmp_instr.rd  = ZERO;
    tmp_instr.csr = CSR_SWAR_CTRLSTAT;
    instr_list.push_back(tmp_instr);
  endfunction


  function void post_randomize();
    if (cfg.enable_swar_extension && (RV32SWAR inside {supported_isa})) begin
      riscv_instr tmp_instr;
      riscv_pseudo_instr li_instr;
      int swar_insts = 0;

      tmp_instr = new();
      li_instr  = new();

      randomize_gpr(li_instr);
      li_instr.pseudo_instr_name = LI;
      li_instr.imm_str = $sformatf("0x%8h # Init swar ctrl", pack_swar_csr_t(r_swar_q[0]));
      instr_list.push_back(li_instr);

      tmp_instr = new();
      tmp_instr = riscv_instr::get_instr(CSRRW);
      tmp_instr.comment = $sformatf(
          "SWAR CTRL RECONF: op: %s  sign %d red %d sat %d norm %d audio %d video %d alu %d res0 %d dyn_rng %d restr %d refblk %d clear %d",
          r_swar_q[0].select.name,
          r_swar_q[0].sign,
          r_swar_q[0].red,
          r_swar_q[0].sat,
          r_swar_q[0].norm,
          r_swar_q[0].audio,
          r_swar_q[0].video,
          r_swar_q[0].alu,
          r_swar_q[0].res0,
          r_swar_q[0].dyn_rng,
          r_swar_q[0].restr,
          r_swar_q[0].refblk,
          r_swar_q[0].ctrl_clear
      );
      if (!(r_swar_q[0].select inside {supported_opcodes})) begin
        `uvm_fatal("SWAR", $sformatf("Constraint not fulfilled %02d", r_swar_q[0].select.name));
      end
      tmp_instr.rs1 = li_instr.rd;
      tmp_instr.rd  = ZERO;
      tmp_instr.csr = CSR_SWAR_CTRLSTAT;
      instr_list.push_back(tmp_instr);

      `uvm_info(`gfn, $sformatf(
                "SWAR INSTR STREAM: Generating %d instructions, reconfig_ratio %d",
                r_num_of_ops,
                r_reconfig_ratio
                ), UVM_LOW);


      for (int i = 0; i < r_num_of_ops; i++) begin
        `uvm_info(`gfn, $sformatf("Randomizing op: new %s", r_ops_q[i].name), UVM_LOW);
        case (r_ops_q[i])
          CALC: begin
            `uvm_info(`gfn, $sformatf("Randomizing swar/calc op: new %d", r_op_swar_other_q[i]),
                      UVM_LOW);
            if (r_op_swar_other_q[i] == 0) begin
              riscv_instr instr = riscv_instr::get_rand_instr(
                  .include_category({ARITHMETIC, RV32F, RV32D}),
                  // .include_category({ARITHMETIC, RV32F, RV32D, JUMP}),
                  .exclude_group({RV32C, RV64C, RV32ZCB, RV64ZCB})
              );
              randomize_gpr(instr);
              instr_list.push_back(instr);
            end else begin
              riscv_swar_instr swar_instr;
              `uvm_info(`gfn, $sformatf("Generating SWAR CALC num %d", swar_insts), UVM_LOW);
              swar_instr = new();
              if (swar_insts % r_reconfig_ratio == 0) reconfigure_ctrl(r_num_of_ops[i+1]);
              `DV_CHECK_RANDOMIZE_FATAL(swar_instr);
              randomize_gpr(swar_instr);
              instr_list.push_back(swar_instr);
              swar_insts++;
            end
          end

          ACCUMULATE_WRITE: begin
            riscv_instr tmp_instr;
            tmp_instr = new();
            tmp_instr = riscv_instr::get_instr(CSRRW);
            randomize_gpr(tmp_instr);
            tmp_instr.csr = CSR_SWAR_ACC_VAL;
            tmp_instr.comment = "SWAR ACC WRITE";
            instr_list.push_back(tmp_instr);
          end
          ACCUMULATE_READ: begin
            riscv_instr tmp_instr;
            tmp_instr = new();
            tmp_instr = riscv_instr::get_instr(CSRRW);
            randomize_gpr(tmp_instr);
            tmp_instr.csr = CSR_SWAR_ACC_VAL;
            tmp_instr.rs1 = ZERO;
            tmp_instr.comment = "SWAR ACC READ";
            instr_list.push_back(tmp_instr);
          end

          ACCUMULATE_SELECT: begin
            riscv_pseudo_instr li_instr;
            riscv_instr tmp_instr;
            r_acc_sel[0] = 0;

            li_instr = new();
            randomize_gpr(li_instr);
            li_instr.pseudo_instr_name = LI;
            li_instr.imm_str = $sformatf("0x%8h", r_acc_sel);
            li_instr.imm = r_acc_sel;
            li_instr.comment = "Load ACC select";
            instr_list.push_back(li_instr);

            tmp_instr = new();
            tmp_instr = riscv_instr::get_instr(CSRRW);
            tmp_instr.comment = "SWAR ACC SELECT";
            tmp_instr.csr = CSR_SWAR_ACC_SEL;
            tmp_instr.rs1 = li_instr.rd;
            instr_list.push_back(tmp_instr);
          end

          default: `uvm_fatal("SWAR", "Randomized unknown op")

        endcase
      end
      super.post_randomize();
    end
  endfunction
endclass
