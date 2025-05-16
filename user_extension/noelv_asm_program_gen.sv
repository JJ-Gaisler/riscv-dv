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
  ;

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
      instr.push_back({indent, $sformatf("li x%0d, 0x%0x", cfg.gpr[0], r_feature)});
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
      li_instr.rd = avail_regs[0];
      li_instr.pseudo_instr_name = LI;
      li_instr.imm_str = $sformatf("0x%0x", r_feature);
      $display(li_instr);
      instr_list.push_back(li_instr);

      //read/write fssr
      tmp_instr = riscv_instr::get_instr(CSRRW);
      tmp_instr.csr = 12'h7c0;
      tmp_instr.rs1 = avail_regs[0];
      tmp_instr.rd = avail_regs[0];
      instr_list.push_back(tmp_instr);
      super.post_randomize();
    end

  endfunction

endclass
