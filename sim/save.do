
mem save -o SRAM.mem -f mti -data hex -addr hex -startaddress 0 -endaddress 262143 -wordsperline 8 /TB/SRAM_component/SRAM_data



 if {[file exists $rtl/RAMSP.ver]} {
	 file delete $rtl/RAMSP.ver
 }

 mem save -o RAMSP.mem -f mti -data hex -addr hex -wordsperline 1 /TB/UUT/M2_unit/M3_unit/RAM_instSP/altsyncram_component/m_default/altsyncram_inst/mem_data
 
 
 if {[file exists $rtl/RAMX.ver]} {
	 file delete $rtl/RAMX.ver
 }

 mem save -o RAMX.mem -f mti -data hex -addr hex -wordsperline 1 /TB/UUT/M2_unit/M3_unit/RAM_instX/altsyncram_component/m_default/altsyncram_inst/mem_data


 if {[file exists $rtl/RAMT.ver]} {
	 file delete $rtl/RAMT.ver
 }

 mem save -o RAMT.mem -f mti -data dec -addr hex -wordsperline 1 /TB/UUT/M2_unit//RAM_instT/altsyncram_component/m_default/altsyncram_inst/mem_data
