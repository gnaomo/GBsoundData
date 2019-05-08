#!/usr/bin/lua
A4=440
C0= A4*math.pow(2, -4.75)
name = {"C_", "C#", "D_", "D#", "E_", "F_", "F#", "G_", "G#", "A_", "A#", "B_"}
p1color=0x3393FFFF
p2color=0xE42121FF
white=0xFFFFFFFF
wcolor=0x26B815FF
ncolor=0xFBE319FF
scrcolor=0x7000EEFF
wramcolor=0xF079ECFF
pulseY=2
wavenoiseY=62
outputsymb = {"L","R"}
function toBits(num,bits)
    -- returns a table of bits, least significant first.
    --bits = bits or math.max(1, select(2, math.frexp(num)))
    local t = {} -- will contain the bits
    for b = bits, 1, -1 do
        t[b] = math.fmod(num, 2)
        num = math.floor((num - t[b]) / 2)
    end
    return t
end
function DecToHex(hex)
	return string.format("%02X", hex)
end
function DecToBin(num,bits)
	return table.concat(toBits(num,bits))
end
function BinToDec(bin)
	bin = string.reverse(bin)
	local sum = 0
	for i = 1, string.len(bin) do
		num = string.sub(bin, i,i) == "1" and 1 or 0
		sum = sum + num * math.pow(2, i-1)
	end
	return sum
end

function round(num, numDecimalPlaces)
  local mult = 10^(numDecimalPlaces or 0)
  return math.floor(num * mult + 0.5) / mult
end

function pitch(freq)
    h = round(12*(math.log(freq/C0))/(math.log(2)))
    octave = math.floor(h / 12)
    n = h % 12
    return string.format("%-2s",name[n+1]).. string.format("%-2s",tostring(octave))
end

function duty(memoryByte)
	--vba.print(string.sub(DecToBin(memory.readbyte(memoryByte),8),1,2))
	if string.format("Wave: %04.1f",BinToDec(string.sub(DecToBin(memory.readbyte(memoryByte),8),1,2))) == 0 then
		return (12.5).."%"
	else
		return string.format("Wave: %04.1f",BinToDec(string.sub(DecToBin(memory.readbyte(memoryByte),8),1,2)) * 2 * 12.5).."%"
	end
end

function lengthData(memoryByte,ccMemory)
	--vba.print(DecToBin(memory.readbyte(memoryByte),8))
	if cc(ccMemory)==0 then
		return "Length: UNLIM"
	else
		return string.format("Length: %02s",DecToHex(math.abs(BinToDec(DecToBin(memory.readbyte(memoryByte),6))-63)))
	end
	--return (64-BinToDec(string.sub(DecToBin(memory.readbyte(memoryByte),8),-5)))*(1/256)
end
function envelope(memoryByte)
	return "Env: "..DecToHex(memory.readbyte(memoryByte))
	--return ("Env:"..BinToDec(string.sub(DecToBin(memory.readbyte(memoryByte),8),5,8)).." "..BinToDec(string.sub(DecToBin(memory.readbyte(memoryByte),8),4,4)).." "..BinToDec(DecToBin(memory.readbyte(memoryByte),3)))
end
function cc(memoryByte)
	return BinToDec(string.sub(DecToBin(memory.readbyte(memoryByte),8),2,2))
end
function sweep(memoryByte)
	return "Sweep: "..DecToHex(math.abs(memory.readbyte(memoryByte)-255))
	--return ("Swp:"..BinToDec(string.sub(DecToBin(memory.readbyte(memoryByte),8),5,7)).." "..BinToDec(string.sub(DecToBin(memory.readbyte(memoryByte),8),4,4)).." "..BinToDec(string.sub(DecToBin(memory.readbyte(memoryByte),8),1,3)))
end
function note(freq)
	return "Note: "..pitch((65536/(2048-BinToDec(freq))))
end
function onOff(memoryByte)
	state=BinToDec(string.sub(DecToBin(memory.readbyte(memoryByte),8),1,1))
	if state == 0 then
		return "Off"
	else
		return "On"
	end
end
function trigger(memoryByte)
	state=BinToDec(string.sub(DecToBin(memory.readbyte(memoryByte),8),1,1))
	if state == 0 then
		return " "
	else
		return "T"
	end
end
function waveLengthData(memoryByte,ccMemory)
	if cc(ccMemory) == 0 then
		return "Length:UNLIM"
	else
		return string.format("Length: %03d",memory.readbyte(memoryByte))
	end
end
function volume(memoryByte)
	v=BinToDec(string.sub(DecToBin(memory.readbyte(memoryByte),8),2,3))
	if v == 0 then
		return "Volume: ".."Mute"
	elseif v == 1 then
		return "Volume: ".."100%"
	elseif v == 2 then
		return "Volume: ".."050%"
	elseif v == 3 then
		return "Volume: ".."025%"
	end
end
function shape(memoryByte)
	return "Shape: "..DecToHex(math.abs(memory.readbyte(memoryByte)-255))
end
function vin(memoryByte)
	return "Vin: "..DecToBin(memory.readbyte(memoryByte),8)
end
function leftandright(memoryByte)
	return "L/R: "..DecToBin(memory.readbyte(memoryByte),8)
end
function soundOnOff(memoryByte)
	return "Sound On/Off: "..DecToBin(memory.readbyte(memoryByte),8)
end
function waveRAM()
	waveTable={}
	j=0
	for i=1,32,2 do
		waveTable[i] = BinToDec(string.sub(DecToBin(memory.readbyte(0xFF30+j),8),1,4))
		waveTable[i+1] = BinToDec(DecToBin(memory.readbyte(0xFF30+j),4))
		j=j+1
	end
	--print(waveTable)
	for i=1,32,1 do
		gui.pixel(15 - i+120+6, 15-waveTable[33-i]+15, white)
	end
end
function output(left,right)
	left=string.sub(DecToBin(memory.readbyte(0xFF25),8),left,left)
	right=string.sub(DecToBin(memory.readbyte(0xFF25),8),right,right)
	if left == "0" then
		left = " "
	else
		left = "L"
	end
	if right == "0" then
		right = " "
	else
		right = "R"
	end
	return "Output: "..left.."/"..right
end
	--waveTable=memory.readword(0xFF30)..memory.readword(0xFF32)..memory.readword(0xFF34)..memory.readword(0xFF36)..memory.readword(0xFF38)..memory.readword(0xFF3A)..memory.readword(0xFF3C)..memory.readword(0xFF3E)
	--return string.sub(DecToBin(memory.readbyte(memoryByte),8),1,4).." "..DecToBin(memory.readbyte(memoryByte),4)
while true do
	
	--PULSE1
	
	pulse1Freq = DecToBin(memory.readbyte(0xFF14),3)..DecToBin(memory.readbyte(0xFF13),8)
	--if trigger(0xFF14) then
	--	p1tcolor = 0x3393FF88
	--	twhite = 0xFFFFFF88
	--else
	--	p1tcolor = 0x3393FFEE
	--	twhite = 0xFFFFFFEE
	--end
	gui.text(2,pulseY + 8 * 0, "Pulse 1", white, p1color)
	--gui.text(2,pulseY + 8 * , cc(0xFF14), white, p1color)
	--gui.text(2,pulseY + 8 * 2, "Note: ",white, p1color)
	gui.text(2,pulseY + 8 * 1, note(pulse1Freq).." "..trigger(0xFF14), twhite, p1color)
	gui.text(2,pulseY + 8 * 2, envelope(0xFF12), white, p1color)
	gui.text(2,pulseY + 8 * 3, output(4,8), white, p1color)
	gui.text(2,pulseY + 8 * 4, duty(0xFF11), white, p1color)
	gui.text(2,pulseY + 8 * 5, lengthData(0xFF11,0xFF14), white, p1color)
	gui.text(2,pulseY + 8 * 6, sweep(0xFF10), white, p1color)
	
	--PULSE 2
	
	pulse2Freq = DecToBin(memory.readbyte(0xFF19),3)..DecToBin(memory.readbyte(0xFF18),8)
	--if trigger(0xFF19) then
	--	p2tcolor = 0xE4212188
	--	twhite = 0xFFFFFF88
	--else
	--	p2tcolor = 0xE42121EE
	--	twhite = 0xFFFFFFEE
	--end
	gui.text(55,pulseY + 8 * 0, "Pulse 2", white, p2color)
	--gui.text(55,pulseY + 8 * 1, cc(0xFF19).." ", white, p2color)
	--gui.text(55,pulseY + 8 * 2, "Note: ",white, p2color)
	gui.text(55,pulseY + 8 * 1, note(pulse2Freq).." "..trigger(0xFF19), twhite, p2color)
	gui.text(55,pulseY + 8 * 2, envelope(0xFF17), white, p2color)
	gui.text(55,pulseY + 8 * 3, output(3,7), white, p2color)
	gui.text(55,pulseY + 8 * 4, duty(0xFF16), white, p2color)
	gui.text(55,pulseY + 8 * 5, lengthData(0xFF16,0xFF19), white, p2color)
	--gui.text(2, 115, "P2:"..duty(0xFF16).." "..lengthData(0xFF16).." "..pitch((65536/(2048-BinToDec(pulse2Freq)))).." "..envelope(0xFF17), white, 0xE42121FF)
	
	--WAVE
	
	waveFreq = DecToBin(memory.readbyte(0xFF1E),3)..DecToBin(memory.readbyte(0xFF1D),8)
	gui.text(2,wavenoiseY + 8 * 0, "Wave", white, wcolor)
	--gui.text(2,wavenoiseY + 8 * 2, cc(0xFF1E), white, wcolor)
	--gui.text(2,wavenoiseY + 8 * 2, "Note: ", white, wcolor)
	gui.text(2,wavenoiseY + 8 * 2, note(waveFreq).." "..trigger(0xFF1E), white, wcolor)
	gui.text(2,wavenoiseY + 8 * 3, volume(0xFF1C), white, wcolor)
	gui.text(2,wavenoiseY + 8 * 4, output(2,6), white, wcolor)
	gui.text(2,wavenoiseY + 8 * 5, waveLengthData(0xFF1B,0xFF1E), white, wcolor)
	gui.text(2,wavenoiseY + 8 * 1, "Power: "..onOff(0xFF1A), white, wcolor)
	--gui.text(2, 82, "Wv:"..pitch((65536/(2048-BinToDec(waveFreq)))).." me too", white, 0x26B815FF)
	
	--NOISE
	
	gui.text(55,wavenoiseY + 8 * 0, "Noise", white, ncolor)
	gui.text(55,wavenoiseY + 8 * 1, envelope(0xFF21).." "..trigger(0xFF23), white, ncolor)
	gui.text(55,wavenoiseY + 8 * 2, output(1,5), white, ncolor)
	gui.text(55,wavenoiseY + 8 * 3, lengthData(0xFF20,0XFF23), white, ncolor)
	gui.text(55,wavenoiseY + 8 * 4, shape(0xFF22), white, ncolor)
	--gui.text(55,wavenoiseY + 8 * 1, cc(0xFF23), white, ncolor)
	
	--SOUND CONTROL REGISTER
	
	gui.text(2,wavenoiseY + 8 * 7, "Sound Control Register", white, scrcolor)
	gui.text(2,wavenoiseY + 8 * 8, vin(0xFF24).."  "..leftandright(0xFF25), white, scrcolor)
	gui.text(2,wavenoiseY + 8 * 9, soundOnOff(0xFF26),white,scrcolor)
	
	--WAVE RAM
	
	gui.text(108,pulseY + 8 * 0, "Wave RAM", white, wcolor)
	gui.box(108, 14, 141, 31, 0x000000AA, wcolor)
	waveRAM()
	--[[
	gui.text(102,pulseY + 8 * 1, "FF30:"..waveRAM(0xFF30), white, wramcolor)
	gui.text(102,pulseY + 8 * 2, "FF31:"..waveRAM(0xFF31), white, wramcolor)
	gui.text(102,pulseY + 8 * 3, "FF32:"..waveRAM(0xFF32), white, wramcolor)
	gui.text(102,pulseY + 8 * 4, "FF33:"..waveRAM(0xFF33), white, wramcolor)
	gui.text(102,pulseY + 8 * 5, "FF34:"..waveRAM(0xFF34), white, wramcolor)
	gui.text(102,pulseY + 8 * 6, "FF35:"..waveRAM(0xFF35), white, wramcolor)
	gui.text(102,pulseY + 8 * 7, "FF36:"..waveRAM(0xFF36), white, wramcolor)
	gui.text(102,pulseY + 8 * 8, "FF37:"..waveRAM(0xFF37), white, wramcolor)
	gui.text(102,pulseY + 8 * 9, "FF38:"..waveRAM(0xFF38), white, wramcolor)
	gui.text(102,pulseY + 8 * 10, "FF39:"..waveRAM(0xFF39), white, wramcolor)
	gui.text(102,pulseY + 8 * 11, "FF3A:"..waveRAM(0xFF3A), white, wramcolor)
	gui.text(102,pulseY + 8 * 11, "FF3B:"..waveRAM(0xFF3B), white, wramcolor)
	gui.text(102,pulseY + 8 * 12, "FF3C:"..waveRAM(0xFF3C), white, wramcolor)
	gui.text(102,pulseY + 8 * 13, "FF3D:"..waveRAM(0xFF3D), white, wramcolor)
	gui.text(102,pulseY + 8 * 14, "FF3E:"..waveRAM(0xFF3E), white, wramcolor)
	gui.text(102,pulseY + 8 * 15, "FF3F:"..waveRAM(0xFF3F), white, wramcolor)
	--]]
	--gui.text(55, 131, "Ns:"..DecToHex(memory.readbyte(0xFF21)).." "..DecToBin(memory.readbyte(0xFF21),8) , white, 0xFBE319FF)
	
	--gui.text(2, 99, "P1:"..DecToHex(BinToDec(pulse1Freq)).." "..pulse1Freq.." "..BinToDec(pulse1Freq).." "..pitch((65536/(2048-BinToDec(pulse1Freq)))), white, 0x3393FFFF)
	
	--gui.text(2, 107, "P2:"..DecToHex(BinToDec(pulse2Freq)).." "..pulse2Freq.." "..BinToDec(pulse2Freq).." "..pitch((65536/(2048-BinToDec(pulse2Freq)))), white, 0xE42121FF)
	
	--gui.text(2, 115, "Wv:"..DecToHex(BinToDec(waveFreq)).." "..waveFreq.." "..BinToDec(waveFreq).." "..pitch((65536/(2048-BinToDec(waveFreq)))), white, 0x26B815FF)
	--gui.text(2, 123, "   Freq2 (NR34):"..DecToHex(memory.readbyte(0xFF1E)).." "..DecToBin(memory.readbyte(0xFF1E),8), white, 0xFFAAFFFF)
	--gui.text(2, 123, "Ns:"..DecToHex(memory.readbyte(0xFF21)).." "..DecToBin(memory.readbyte(0xFF21),8) , white, 0xFBE319FF)
	--if (DecToHex(memory.readbyte(0xFF1D))) ~= b then
		--vba.print(DecToHex(memory.readbyte(0xFF1D)).."----"..table.concat(toBits(memory.readbyte(0xFF1D))))
	--end
	--b=DecToHex(memory.readbyte(0xFF1D))
	vba.frameadvance()
end


--vba.message(tostring(memory.readword(FF18))
--D6 La3
--C4 Sol#3
