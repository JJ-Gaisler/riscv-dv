# Add user macros, routines in this file
.macro swari rd, rs2, rs1
.insn r CUSTOM_1, 0x0, 0x0, \rd, \rs1, \rs2
.endm
.macro swaradd8 rd, rs1, rs2, red, sat, norm, sgnd
  .insn r CUSTOM_1, (4 * \norm + 2 * \sat + \red), ((\sgnd << 6) + (2 << 3) + 0), \rd, \rs1, \rs2
.endm
.macro swarsub8 rd, rs1, rs2, red, sat, norm, sgnd
  .insn r CUSTOM_1, (4 * \norm + 2 * \sat + \red), ((\sgnd << 6) + (2 << 3) + 1), \rd, \rs1, \rs2
.endm
.macro swarmul8 rd, rs1, rs2, red, sat, norm, sgnd
  .insn r CUSTOM_1, (4 * \norm + 2 * \sat + \red), ((\sgnd << 6) + (2 << 3) + 2), \rd, \rs1, \rs2
.endm
.macro swarshr8 rd, rs1, rs2, red, sat, norm, sgnd
  .insn r CUSTOM_1, (4 * \norm + 2 * \sat + \red), ((\sgnd << 6) + (2 << 3) + 3), \rd, \rs1, \rs2
.endm
.macro swaradd16 rd, rs1, rs2, red, sat, norm, sgnd
  .insn r CUSTOM_1, (4 * \norm + 2 * \sat + \red), ((\sgnd << 6) + (1 << 3) + 0), \rd, \rs1, \rs2
.endm
.macro swarsub16 rd, rs1, rs2, red, sat, norm, sgnd
  .insn r CUSTOM_1, (4 * \norm + 2 * \sat + \red), ((\sgnd << 6) + (1 << 3) + 1), \rd, \rs1, \rs2
.endm
.macro swarmul16 rd, rs1, rs2, red, sat, norm, sgnd
  .insn r CUSTOM_1, (4 * \norm + 2 * \sat + \red), ((\sgnd << 6) + (1 << 3) + 2), \rd, \rs1, \rs2
.endm
.macro swarshr16 rd, rs1, rs2, red, sat, norm, sgnd
  .insn r CUSTOM_1, (4 * \norm + 2 * \sat + \red), ((\sgnd << 6) + (1 << 3) + 3), \rd, \rs1, \rs2
.endm

