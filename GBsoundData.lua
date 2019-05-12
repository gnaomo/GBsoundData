#!/usr/bin/lua

--[[ Please before trying to understand this mess look to these pages:
    http://tasvideos.org/EmulatorResources/VBA/LuaScriptingFunctions.html
    http://gbdev.gg8.se/wiki/articles/Gameboy_sound_hardware
    http://marc.rawer.de/Gameboy/Docs/GBCPUman.pdf
]]

A4=440 --This defines note A4 frequency
C0= A4*math.pow(2, -4.75) --Note C0 is calculated from note A4
name = {"C_", "C#", "D_", "D#", "E_", "F_", "F#", "G_", "G#", "A_", "A#", "B_"} --When a note is not sharpened an underscore is displayed (_) instead of the sharp symbol (#) to fill the gap

--COLOR CODES
--[[HTML color code format is used, there is also transparency
	0xRRGGBBTT
		R=RED
		G=GREEN
		B=BLUE
		T=TRANSPARENCY
]]
white=0xFFFFFFFF --Used for text and for the WaveRAM graph line
p1Color=0x3393FFFF --Pulse 1 text border color
p2Color=0xE42121FF --Pulse 2 text border color
wColor=0x26B815FF --Wave text border color
nColor=0xFBE319FF --Noise text border color
scrColor=0x7000EEFF --Sound Control Register (SCR) border color
wramColor=0xF079ECFF -- WaveRAM graph border color
pulse1Y = 2
pulse2Y = 2
wramY = 2 -- Pulse 1,2 and waveram section Y coordinate
waveY = 62
noiseY = 62
scrY = 62 --Wave, noise and SCR section Y coordinate

function toBits(num,bits)
--Convert number to binary, output length is defined with the variable "bits"
    -- returns a table of bits, least significant first
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
--Given the frequency the function returns the actual note played alongside the octave
    h = round(12*(math.log(freq/C0))/(math.log(2)))
    octave = math.floor(h / 12)
    n = h % 12
    return string.format("%-2s",name[n+1]).. string.format("%-2s",tostring(octave))
end

function duty(memoryByte)
--[[Returns duty cycle of Pulse 1 or 2
	It's 2 bit long -> 4 possible values
		00 -> 00 -> 12.5%
		01 -> 01 -> 25.0%
		10 -> 02 -> 50.0%
		11 -> 03 -> 75.0%
	12.5% and 75% have the same duty
]]
	if string.format("Wave: %04.1f",BinToDec(string.sub(DecToBin(memory.readbyte(memoryByte),8),1,2))) == 0 then
		return (12.5).."%"
	-- "String.sub([binaryNumber],1,2)" select the first 2 most significant bits 
	else
		return string.format("Wave: %04.1f",BinToDec(string.sub(DecToBin(memory.readbyte(memoryByte),8),1,2)) * 2 * 12.5).."%"
	end
end

function lengthData(memoryByte,ccMemory)
--[[Returns lenghtData of Pulse 1,2 or Noise
	It's 6 bit long -> 64 possible values (t1: 0-63)
	Sound Length = (64-t1)*(1/256) seconds
]]
	if cc(ccMemory)==0 then
	--lengthData is not used (that means the sound has "unlimited" length) if counter/consecutive bit is 0
		return "Length: UNLIM"
	else
	--Value written in Hex because in LSDJ it's written like that
	--DecToBin([decimalNumber],6) select the first 6 least significant bits 
		return string.format("Length: %02s",DecToHex(math.abs(BinToDec(DecToBin(memory.readbyte(memoryByte),6))-63)))
	end
end
function envelope(memoryByte)
	--Value written in Hex because in LSDJ it's written like that
	return "Env: "..DecToHex(memory.readbyte(memoryByte))
end
function cc(memoryByte)
	--"String.sub([binaryNumber],2,2)" select only bit 6
	return BinToDec(string.sub(DecToBin(memory.readbyte(memoryByte),8),2,2))
end
function sweep(memoryByte)
	--[[Value written in Hex because in LSDJ it's written like that,
		also LSDJ treats FF as minimum sweep and 00 as maximum (usually 00 is minimum and FF is maximum) 
		so i had to "reverse" the output
	]]
	return "Sweep: "..DecToHex(math.abs(memory.readbyte(memoryByte)-255))
end
function note(freq)
	--[[Frequency is not in Hz so it needs to be converted:
			Frequency = 131072/(2048-x) Hz
		and then sent to pitch() to be converted to a note
		the formula applies to Pulse 1 channel and 2
	]]
	
	return "Note: "..pitch((131072/(2048-BinToDec(freq))))
end
function waveNote(freq)
	--[[Frequency is not in Hz so it needs to be converted:
			Frequency = 65536/(2048-x) Hz
		and then sent to pitch() to be converted to a note
		the formula applies only to the Wave channel
	]]
	return "Note: "..pitch((65536/(2048-BinToDec(freq))))
end
function onOff(memoryByte)
	--[["String.sub([binaryNumber],1,1)" select only bit 7
		used only in wave channel
	]]
	state=BinToDec(string.sub(DecToBin(memory.readbyte(memoryByte),8),1,1))
	if state == 0 then
		return "Off"
	else
		return "On"
	end
end
function trigger(memoryByte)
	--[["String.sub([binaryNumber],1,1)" select only bit 7
		"When set (1) sound restarts, a T appears near note or envelope"
	]]
	state=BinToDec(string.sub(DecToBin(memory.readbyte(memoryByte),8),1,1))
	if state == 0 then
		return " "
	else
		return "T"
	end
end
function waveLengthData(memoryByte,ccMemory)
--[[Returns lenghtData of Pulse 1,2 or Noise
	It's 8 bit long -> 256 possible values (t1: 0-63)
	Sound Length = (256-t1)*(1/2) seconds
	I think it's unused
]]
	if cc(ccMemory) == 0 then
		return "Length:UNLIM"
	else
		return string.format("Length: %03d",DecToHex(math.abs(BinToDec(DecToBin(memory.readbyte(memoryByte),8))-255)))
	end
end
function volume(memoryByte)
--[[Returns wave volume
	It's 2 bit long -> 4 possible values
		00 -> 00 -> Mute
		01 -> 01 -> 100.0%
		10 -> 02 -> 50.0%
		11 -> 03 -> 25.0%
]]
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

while true do
	
	--PULSE1
	
	pulse1Freq = DecToBin(memory.readbyte(0xFF14),3)..DecToBin(memory.readbyte(0xFF13),8)
	gui.text(2,pulse1Y + 8 * 0, "--Pulse 1--", white, p1Color)
	gui.text(2,pulse1Y + 8 * 1, note(pulse1Freq).." "..trigger(0xFF14), twhite, p1Color)
	gui.text(2,pulse1Y + 8 * 2, envelope(0xFF12), white, p1Color)
	gui.text(2,pulse1Y + 8 * 3, output(4,8), white, p1Color)
	gui.text(2,pulse1Y + 8 * 4, duty(0xFF11), white, p1Color)
	gui.text(2,pulse1Y + 8 * 5, lengthData(0xFF11,0xFF14), white, p1Color)
	gui.text(2,pulse1Y + 8 * 6, sweep(0xFF10), white, p1Color)
	
	--PULSE 2
	
	pulse2Freq = DecToBin(memory.readbyte(0xFF19),3)..DecToBin(memory.readbyte(0xFF18),8)
	gui.text(55,pulse2Y + 8 * 0, "--Pulse 2--", white, p2Color)
	gui.text(55,pulse2Y + 8 * 1, note(pulse2Freq).." "..trigger(0xFF19), twhite, p2Color)
	gui.text(55,pulse2Y + 8 * 2, envelope(0xFF17), white, p2Color)
	gui.text(55,pulse2Y + 8 * 3, output(3,7), white, p2Color)
	gui.text(55,pulse2Y + 8 * 4, duty(0xFF16), white, p2Color)
	gui.text(55,pulse2Y + 8 * 5, lengthData(0xFF16,0xFF19), white, p2Color)
	
	--WAVE
	
	waveFreq = DecToBin(memory.readbyte(0xFF1E),3)..DecToBin(memory.readbyte(0xFF1D),8)
	gui.text(2,waveY + 8 * 0, "--Wave--", white, wColor)
	gui.text(2,waveY + 8 * 2, waveNote(waveFreq).." "..trigger(0xFF1E), white, wColor)
	gui.text(2,waveY + 8 * 3, volume(0xFF1C), white, wColor)
	gui.text(2,waveY + 8 * 4, output(2,6), white, wColor)
	gui.text(2,waveY + 8 * 5, waveLengthData(0xFF1B,0xFF1E), white, wColor)
	gui.text(2,waveY + 8 * 1, "Power: "..onOff(0xFF1A), white, wColor)
	
	--NOISE
	
	gui.text(55,noiseY + 8 * 0, "--Noise--", white, nColor)
	gui.text(55,noiseY + 8 * 1, envelope(0xFF21).." "..trigger(0xFF23), white, nColor)
	gui.text(55,noiseY + 8 * 2, output(1,5), white, nColor)
	gui.text(55,noiseY + 8 * 3, lengthData(0xFF20,0XFF23), white, nColor)
	gui.text(55,noiseY + 8 * 4, shape(0xFF22), white, nColor)
	
	--SOUND CONTROL REGISTER
	
	gui.text(2,scrY + 8 * 7, "--Sound Control Register--", white, scrColor)
	gui.text(2,scrY + 8 * 8, vin(0xFF24).."  "..leftandright(0xFF25), white, scrColor)
	gui.text(2,scrY + 8 * 9, soundOnOff(0xFF26),white,scrColor)
	
	--WAVE RAM
	
	gui.text(108,wramY + 8 * 0, "Wave RAM", white, wColor)
	gui.box(108, 14, 141, 31, 0x000000AA, wColor)
	waveRAM()
	
	vba.frameadvance()
end
