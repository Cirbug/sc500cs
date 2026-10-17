"""VID2 frame ownership, RAW validation, and existing SD/DDR regressions."""
from pathlib import Path
import argparse, subprocess
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--modelsim',default='F:/modelsim/win64')
p.add_argument('--out',type=Path,required=True)
p.add_argument('--tops',nargs='+')
a=p.parse_args();root=Path(__file__).resolve().parent.parent;h=root/'user_source/hdl_source';ip=root/'user_source/ip_source'
out=a.out.resolve();out.mkdir(parents=True,exist_ok=True);tool=Path(a.modelsim)
fifo128=[ip/'w128_d512_fifo/w128_d512_fifo.v',ip/'w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v']
fifo155=list((ip/'w155_d512_fifo').glob('*.v'))
cases={
 'tb_video_crop_guard':[h/'video_in.v']+fifo128,
 'tb_csi_vendor_aligners':[h/'mipi_dphy_rx/byte_aligner.enc.v',h/'mipi_dphy_rx/channel_aligner.enc.v',h/'mipi_dphy_rx/byte_aligner_wrapper.enc.sv',h/'mipi_dphy_rx/channel_aligner_wrapper.enc.sv',h/'isp/csi_unpacket_2lane.v'],
 'tb_video_error_details':[h/'isp/csi_unpacket_2lane.v'],
 'tb_csi_header_guard':[h/'isp/csi_unpacket_2lane.v'],
 'tb_csi_legacy_equivalence':[h/'isp/csi_unpacket_2lane.v',root/'tests/fixtures/csi_unpacket_legacy.v'],
 'tb_csi_hs_tail':[h/'isp/csi_unpacket_2lane.v'],
 'tb_csi_packet_boundaries':[h/'isp/csi_unpacket_2lane.v'],
 'tb_video_full_pipeline':[h/'isp/csi_unpacket_2lane.v',h/'isp/raw10_unpacket_2lane.v',
    h/'isp/uial2axis.v',h/'isp/isp_top.v',h/'awb.v',h/'picture_control.v',
    h/'isp/data128_96/data128_96.v',h/'isp/data96_128/data96_128.v',h/'video_in.v']
    +list((h/'isp/demosaic_4x_2_0').glob('*.v'))+fifo128,
 'tb_video_diag_cdc':[],
 'tb_video_rx_integrity':[h/'isp/csi_unpacket_2lane.v'],
 'tb_video_safe_buffers':[h/'video_in.v',h/'video_out.v']+fifo128,
 'tb_sd_recorder_recovery':[h/'sd_recorder.v'],
 'tb_sd_recorder_fullframe':[h/'sd_recorder.v'],
 'tb_sd_recorder_mailbox':[h/'sd_recorder.v'],
 'tb_sd_ddr_startup_capture':[h/'sd_recorder.v',h/'mc_to_user_interface.v']+fifo155,
 'tb_sd_ddr_handshake':[h/'mc_to_user_interface.v',h/'ph1p35_ddr/ph1p35_324_ddr_wrapper.v'],
}
for top in a.tops or cases:
    lib=out/(top+'_lib');log=out/(top+'.log');script=out/(top+'.do')
    if not lib.exists(): subprocess.run([str(tool/'vlib.exe'),str(lib)],check=True,capture_output=True)
    tb=root/'tests'/(top+('.sv' if (root/'tests'/(top+'.sv')).exists() else '.v'))
    sources=cases[top]+[tb]
    script.write_text('onerror {quit -code 1 -force}\nonbreak {quit -code 1 -force}\n'
        +'vlog -sv -work {'+lib.as_posix()+'} {+incdir+'+h.as_posix()+'} '
        +'{+incdir+'+(root/'tests').as_posix()+'} '+' '.join('{'+s.as_posix()+'}' for s in sources)
        +'\nvsim -lib {'+lib.as_posix()+'} '+top+'\nrun -all\nquit -code 0 -force\n')
    result=subprocess.run([str(tool/'vsim.exe'),'-c','-do',str(script),'-l',str(log)],cwd=out,capture_output=True,text=True)
    text=log.read_text(errors='replace')
    if result.returncode or 'PASS' not in text or '** Error' in text or '** Fatal' in text:
        raise RuntimeError(f'{top} failed; {log}\n{text[-2200:]}')
    print('\n'.join(l for l in text.splitlines() if 'PASS' in l),flush=True)
