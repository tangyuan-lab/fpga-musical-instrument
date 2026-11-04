`ifndef DAMPING_DEFAULTS_VH
`define DAMPING_DEFAULTS_VH
// Packed word [23:22] mode: legacy/normal/fast/palm;
// [21:20] high-frequency loss shift 0..3; [19:0] base UQ0.24 loss.
// Native-frequency bands: <600Hz, 600..2500Hz, >=2500Hz.
// These follow the native model when transposed; they are not an audio LPF.
`define DAMPING_PIANO_DEFAULT 32'h00603460
`define DAMPING_GUITAR_DEFAULT 32'h00608699
`define DAMPING_BASS_DEFAULT 32'h006055af
`define DAMPING_DEFAULTS {`DAMPING_BASS_DEFAULT,`DAMPING_GUITAR_DEFAULT,`DAMPING_PIANO_DEFAULT}
`endif
