--[[ Please before trying to understand this mess look at these pages:
    http://https://tasvideos.org/Bizhawk/LuaFunctions
    http://gbdev.gg8.se/wiki/articles/Gameboy_sound_hardware
    http://marc.rawer.de/Gameboy/Docs/GBCPUman.pdf
]]

memory.usememorydomain("System Bus")
gui.defaultPixelFont("0")

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
p1Color=0xFF3393FF --Pulse 1 text border color
p2Color=0xFFE42121 --Pulse 2 text border color
wColor=0xFF26B815 --Wave text border color
nColor=0xFFFBE319 --Noise text border color
scrColor=0xFF7000EE --Sound Control Register (SCR) border color
wramColor=0xAA26B815 -- WaveRAM graph back color

textPixelHeight = 8

pulse1X = 2
pulse1Y = 2

pulse2X = 55
pulse2Y = 2

waveX = 2
waveY = 62

noiseX = 55
noiseY = 62

scrX = 2
scrY = 62 --Wave, noise and SCR section Y coordinate

wramX = 108
wramY = 2 -- Pulse 1,2 and waveram section Y coordinate

local register = {} -- List of registers later to be filled with addresses from 0xFF10 to 0xFF30, this is because we have to workaround memory.readbyte(), it always returns FF with some sound registers (https://gbdev.gg8.se/wiki/articles/Gameboy_sound_hardware#Register_Reading), so we use event.onmemorywrite() to catch write changes

function DecToHex(hex)
	return string.format("%02X", hex)
end

--Gambatte makes val always = 0 so we workaround that by using emu.getregister("A") (thank you CasualPokePLayer#8731 from the TasVideos Discord)
function setAddressesValue(addr, val, flags)
	register[""..DecToHex(addr)] = emu.getregister("A")
end
for i=0,47,1 do
	event.onmemorywrite(setAddressesValue, 0xFF10 + i)
	register["FF"..DecToHex(16+i)] = 0
end

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
	if string.format("Wave: %04.1f",BinToDec(string.sub(DecToBin((memoryByte),8),1,2))) == 0 then
		return (12.5).."%"
	-- "String.sub([binaryNumber],1,2)" select the first 2 most significant bits 
	else
		return string.format("Wave: %04.1f",BinToDec(string.sub(DecToBin((memoryByte),8),1,2)) * 2 * 12.5).."%"
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
		return string.format("Length: %02s",DecToHex(math.abs(BinToDec(DecToBin((memoryByte),6))-63)))
	end
end
function envelope(memoryByte)
	--Value written in Hex because in LSDJ it's written like that
	return "Env: "..DecToHex((memoryByte))
end
function cc(memoryByte)
	--"String.sub([binaryNumber],2,2)" select only bit 6
	return BinToDec(string.sub(DecToBin((memoryByte),8),2,2))
end
function sweep(memoryByte)
	--[[Value written in Hex because in LSDJ it's written like that,
		also LSDJ treats FF as minimum sweep and 00 as maximum (usually 00 is minimum and FF is maximum) 
		so i had to "reverse" the output
	]]
	return "Sweep: "..DecToHex(math.abs((memoryByte)-255))
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
	state=BinToDec(string.sub(DecToBin((memoryByte),8),1,1))
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
	state=BinToDec(string.sub(DecToBin((memoryByte),8),1,1))
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
		return string.format("Length: %03d",DecToHex(math.abs(BinToDec(DecToBin((memoryByte),8))-255)))
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
	v=BinToDec(string.sub(DecToBin((memoryByte),8),2,3))
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
--[[Value written in Hex because in LSDJ it's written like that,
		also LSDJ treats FF as minimum shape and 00 as maximum (usually 00 is minimum and FF is maximum) 
		so the output is kinda "reversed"
	]]
	return "Shape: "..DecToHex(math.abs((memoryByte)-255))
end
function vin(memoryByte)
--Vin is apparentely unused
	return "Vin: "..DecToBin((memoryByte),8)
end
function leftandright(memoryByte)
	return "L/R: "..DecToBin((memoryByte),8)
end
function soundOnOff(memoryByte)
	return "Sound On/Off: "..DecToBin((memoryByte),8)
end
function waveRAM()
--[[Wave Graph is 32x16
1 byte has 2 4 bit long Y coordinates
there are 16 bytes total so a wave table is long 32
]]
	waveTable={}
	j=0
	for i=1,32,2 do
		waveTable[i] = BinToDec(string.sub(DecToBin(register["FF"..DecToHex(48+j)],8),1,4))
		waveTable[i+1] = BinToDec(DecToBin(register["FF"..DecToHex(48+j)],4))
		j=j+1
	end
--Graph Line coordinates
	for i=1,32,1 do
		gui.drawPixel(141-i, 30-waveTable[33-i], white)
	end
end
function output(left,right)
--[[TO DO
	Make L/R transparent when not active
]]
	left=string.sub(DecToBin((register.FF25),8),left,left)
	right=string.sub(DecToBin((register.FF25),8),right,right)
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
  --[[
  Pulse 1, Pulse 2 and Wave channel frequency each is long 11 bits so 8 + 3 bits must be connected from 2 seperate registers
  ]]
	--PULSE1
	--print(pulse1Freqq,bo)
	pulse1Freq = DecToBin(register.FF14,3)..DecToBin(register.FF13,8)
	gui.pixelText(pulse1X,pulse1Y + textPixelHeight * 0, "--Pulse 1--", white, p1Color)
	gui.pixelText(pulse1X,pulse1Y + textPixelHeight * 1, note(pulse1Freq).." "..trigger(register.FF14), twhite, p1Color)
	gui.pixelText(pulse1X,pulse1Y + textPixelHeight * 2, envelope(register.FF12), white, p1Color)
	gui.pixelText(pulse1X,pulse1Y + textPixelHeight * 3, output(4,8), white, p1Color)
	gui.pixelText(pulse1X,pulse1Y + textPixelHeight * 4, duty(register.FF11), white, p1Color)
	gui.pixelText(pulse1X,pulse1Y + textPixelHeight * 5, lengthData(register.FF11,register.FF14), white, p1Color)
	gui.pixelText(pulse1X,pulse1Y + textPixelHeight * 6, sweep(register.FF10), white, p1Color)
	
	--PULSE 2
	
	pulse2Freq = DecToBin((register.FF19),3)..DecToBin((register.FF18),8)
	gui.pixelText(pulse2X,pulse2Y + textPixelHeight * 0, "--Pulse 2--", white, p2Color)
	gui.pixelText(pulse2X,pulse2Y + textPixelHeight * 1, note(pulse2Freq).." "..trigger(register.FF19), twhite, p2Color)
	gui.pixelText(pulse2X,pulse2Y + textPixelHeight * 2, envelope(register.FF17), white, p2Color)
	gui.pixelText(pulse2X,pulse2Y + textPixelHeight * 3, output(3,7), white, p2Color)
	gui.pixelText(pulse2X,pulse2Y + textPixelHeight * 4, duty(register.FF16), white, p2Color)
	gui.pixelText(pulse2X,pulse2Y + textPixelHeight * 5, lengthData(register.FF16,register.FF19), white, p2Color)
	                           
	--WAVE
	
	waveFreq = DecToBin((register.FF1E),3)..DecToBin((register.FF1D),8)
	gui.pixelText(waveX,waveY + textPixelHeight * 0, "--Wave--", white, wColor)
	gui.pixelText(waveX,waveY + textPixelHeight * 2, waveNote(waveFreq).." "..trigger(register.FF1E), white, wColor)
	gui.pixelText(waveX,waveY + textPixelHeight * 3, volume(register.FF1C), white, wColor)
	gui.pixelText(waveX,waveY + textPixelHeight * 4, output(2,6), white, wColor)
	gui.pixelText(waveX,waveY + textPixelHeight * 5, waveLengthData(register.FF1B,register.FF1E), white, wColor)
	gui.pixelText(waveX,waveY + textPixelHeight * 1, "Power: "..onOff(register.FF1A), white, wColor)
	                       
	--NOISE
	
	gui.pixelText(noiseX,noiseY + textPixelHeight * 0, "--Noise--", white, nColor)
	gui.pixelText(noiseX,noiseY + textPixelHeight * 1, envelope(register.FF21).." "..trigger(register.FF23), white, nColor)
	gui.pixelText(noiseX,noiseY + textPixelHeight * 2, output(1,5), white, nColor)
	gui.pixelText(noiseX,noiseY + textPixelHeight * 3, lengthData(register.FF20,register.FF23), white, nColor)
	gui.pixelText(noiseX,noiseY + textPixelHeight * 4, shape(register.FF22), white, nColor)
	                         
	--SOUND CONTROL REGISTER 
	
	gui.pixelText(scrX,scrY + textPixelHeight * 7, "--Sound Control Register--", white, scrColor)
	gui.pixelText(scrX,scrY + textPixelHeight * 8, vin(register.FF24).."  "..leftandright(register.FF25), white, scrColor)
	gui.pixelText(scrX,scrY + textPixelHeight * 9, soundOnOff(register.FF26),white,scrColor)
	
	--WAVE RAM
	
	gui.pixelText(wramX,wramY + textPixelHeight * 0, "Wave RAM", white, wColor)
	gui.drawBox(108, 14, 141, 31, 0xAA000000, wramColor)
	waveRAM()
	emu.frameadvance()
end
