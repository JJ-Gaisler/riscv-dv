class riscv_swar_instr extends riscv_instr;
  `uvm_object_utils(riscv_swar_instr)

  function new(string name = "");
    super.new(name);
    this.group = RV32SWAR;
    this.instr_name = SWAR;
  endfunction : new

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
      SWAR: get_opcode = 7'b0101011;
      default: get_opcode = super.get_opcode();
    endcase
  endfunction : get_opcode

  virtual function string convert2bin(string prefix = "");
    `uvm_fatal("SWAR", "Not supported!");
    return {prefix, $sformatf("0x%8h", {get_func7(), rs2, rs1, get_func3(), rd, get_opcode()})};
  endfunction : convert2bin

  virtual function string convert2asm(string prefix = "");
    string asm_str_final;
    string asm_str;

    if (this.group != RV32SWAR) begin
      $stacktrace;
      `uvm_fatal("SWAR", $sformatf("We shouldn't end up here %s %s", this.group, get_instr_name()));
      return super.convert2asm(prefix);
    end

    asm_str = format_string(get_instr_name(), MAX_INSTR_STR_LEN);

    asm_str_final =
        $sformatf("%0s%s, %s, %s # swar instr", asm_str, rd.name(), rs1.name(), rs2.name());
    if (asm_str_final == "") begin
      return super.convert2asm(prefix);
    end

    if (comment != "") begin
      asm_str_final = {asm_str_final, " #", comment};
    end

    return asm_str_final.tolower();

  endfunction

endclass
