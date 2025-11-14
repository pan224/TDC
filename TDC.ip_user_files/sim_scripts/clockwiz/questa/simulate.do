onbreak {quit -f}
onerror {quit -f}

vsim -lib xil_defaultlib clockwiz_opt

do {wave.do}

view wave
view structure
view signals

do {clockwiz.udo}

run -all

quit -force
