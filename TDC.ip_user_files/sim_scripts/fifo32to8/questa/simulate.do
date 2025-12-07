onbreak {quit -f}
onerror {quit -f}

vsim -lib xil_defaultlib fifo32to8_opt

do {wave.do}

view wave
view structure
view signals

do {fifo32to8.udo}

run -all

quit -force
