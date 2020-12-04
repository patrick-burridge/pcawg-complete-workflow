
# TODO describe and test#!/usr/bin/env cwl-runner

class: Workflow
id: "pcawg-complete-workflow"
label: "pcawg-complete-workflow"
cwlVersion: v1.2
doc: |
    This is the complete pcawg workflow

dct:creator:
  "@id": "https://orcid.org/0000-0001-7564-3615"
  foaf:name: "Patrick Burridge"
  foaf:mbox: "mailto:patrick.burridge@gmail.com"

$namespaces:
    dct: http://purl.org/dc/terms/
    foaf: http://xmlns.com/foaf/0.1/

requirements:
  SubworkflowFeatureRequirement: {}

inputs:
  tumor:
    type: File
    secondaryFiles:
    - .bai
  normal:
    type: File
    secondaryFiles:
    - .bai
  references:
    # https://dcc.icgc.org/releases/PCAWG/reference_data/
  ramcpuhddetc:
    # resource allocations

outputs:
  snv_indel: 
    type: File
    outputSource: biasfilter/output_vcf_file
  sv: 
    type: File
    outputSource: svmerge/somatic_sv_vcf


steps:
  ########################################
  # Alignment                            #
  ########################################
  # TODO describe and test
  alignment_normal:
    run: Seqware-BWA-Workflow/Dockstore.cwl
    in:
      output_file_basename: $(inputs.normal.basename)
      download_reference_files: "false"
      reads: normal
      output_dir: "/tmp"
      reference_gz:
      reference_gz_fai:
      reference_gz_pac:
      reference_gz_amb:
      reference_gz_bwt:
      reference_gz_sa:
      reference_gz_ann:
    out:
      merged_output_bai
      merged_output_unmapped_metrics
      merged_output_bam
      merged_output_metrics
      merged_output_unmapped_bai
      merged_output_unmapped_bam

  alignment_tumor:
    run: Seqware-BWA-Workflow/Dockstore.cwl
    in:
      output_file_basename: $(inputs.tumor.basename)
      download_reference_files: "false"
      reads: tumor
      output_dir: "/tmp"
      reference_gz:
      reference_gz_fai:
      reference_gz_pac:
      reference_gz_amb:
      reference_gz_bwt:
      reference_gz_sa:
      reference_gz_ann:
    out:
      merged_output_bai
      merged_output_unmapped_metrics
      merged_output_bam
      merged_output_metrics
      merged_output_unmapped_bai
      merged_output_unmapped_bam

  ########################################
  # Sanger-CGP                           #
  ########################################
  # TODO describe and test
  sanger:
    run: CGP-Somatic-Docker/Dockstore.cwl
    in:
      tumor: alignment_tumor/zzz
      normal: alignment_normal/zzz
      refFrom:
      bbFrom:
      coreNum:
      memGB:
      run-id:
    out:
      somatic_cnv_vcf_gz
      somatic_cnv_tar_gz
      somatic_indel_vcf_gz
      somatic_indel_tar_gz
      somatic_sv_vcf_gz
      somatic_sv_tar_gz
      somatic_snv_mnv_vcf_g
      somatic_snv_mnv_tar_gz
      somatic_genotype_tar_gz
      somatic_imputeCounts_tar_gz
      somatic_verifyBamId_tar_g
      bas_tar_gz
      qc_metrics
      timing_metrics

  ########################################
  # DKFZ                                 #
  ########################################
  # TODO describe and test
  dkfz:
    run: dkfz_dockered_workflows/Dockstore.cwl
    in:
      normal-bam: 
      tumor-bam: 
      reference-gz: 
      delly-bedpe: 
      run-id:
    out:
      somatic_cnv_tar_gz
      somatic_cnv_vcf_gz
      germline_indel_vcf_gz
      somatic_indel_tar_gz
      somatic_indel_vcf_gz
      germline_snv_mnv_vcf_gz
      somatic_snv_mnv_tar_gz
      somatic_snv_mnv_vcf_gz
      qc_metrics

  ########################################
  # gatk cocleaning                      #
  ########################################
  # TODO describe and test
  cocleaning:
    run: pcawg-gatk-cocleaning/gatk-cocleaning-workflow.cwl
    in:
      tumor_bam:
      normal_bam:
      knownIndels:
      knownSites:
      reference:
    out:
      cleaned_tumor_bam
      cleaned_normal_bam

  ########################################
  # muse                                 #
  ########################################
  # TODO describe and test
  muse:
    run: pcawg-muse/muse.cwl
    in:
      tumor: cocleaning/cleaned_tumor_bam
      normal: cocleaning/cleaned_normal_bam
      reference:
      known:
      mode:
      coreNum:
      run-id:
    out:
      somatic_snv_mnv_vcf_gz

  ########################################
  # broad                                #
  ########################################
  # TODO describe and test
  # TODO running the WDL with cromwell and pcawg test files, the oxoQ score generation fails 
  #      because of unknown problem where there is mismatch between output 'chromosome names/counts'
  #      and the reference file 'chromosome names/counts'. 
  #      Also obnoxious is that the container requires priveledged to execute and
  #      doesn't translate into cwl easily.. like it makes more sense to have cwl 
  #      just executing cromwell.. 
  # TODO Unsure whether to try to mend container/get oxoQ scores different way or 
  #      whether to pull something more novel together from actively updated 
  #      GATK wdl repos.
  broad:
    run pcawg-broad-wgs-variant-caller/pcawg-broad-workflow-tool.cwl
    in:
      bam_tumor:
      bam_normal:
      bam_tumor_index:
      bam_normal_index:
      refdata1:
      output_disk_gb:
      ram_gb:
      cpu_cores:
    out:
      sample_oxoQ_txt:
      sample_broad_dRanger_svaba_DATECODE_somatic_sv_vcf_gz
      sample_broad_mutect_DATECODE_somatic_snv_mnv_vcf_gz

  ########################################
  # delly                                #
  ########################################
  # TODO describe and test
  delly:
    run: pcawg_delly_workflow/delly_docker/Dockstore.cwl
    in:
      run-id:
      reference-gc:
      tumor-bam:
      normal-bam:
      reference-gz:
    out:
      somatic_sv_vcf
      germline_sv_vcf
      sv_vcf
      somatic_bedpe
      somatic_bedpe_tar_gz
      germline_bedpe
      germline_bedpe_tar_gz
      somatic_sv_readname
      germline_sv_readname
      cov
      cov_plots
      sv_log
      sv_qc
      sv_timing

  ########################################
  # svmerge                              #
  ########################################
  # TODO describe and test
  svmerge:
    run: pcawg_sv_merge/Dockstore.cwl
    in:
      run_id:
      dranger:
      snowman:
      brass:
      delly:
    out:
      log
      somatic_sv_bedpe
      somatic_sv_full_bedpe
      somatic_sv_full_vcf
      somatic_sv_full_tbi
      somatic_sv_tbi
      somatic_sv_vcf
      somatic_sv_stat
      sv_tar

  ########################################
  # oxog                                 #
  ########################################
  # TODO describe and test
  oxog:
    run: OxoG-Dockstore-Tools/oxog_varbam_annotate_wf.cwl
    in:
      inputFileDirectory:
      refFile:
      out_dir:
      normalBam:
      padding:
      padding:
      padding:
      refDataDir:
      minibamName:
      vcfdir:
      tumours:
    out:
      oxog_filtered_files
      minibams
      annotated_files

  ########################################
  # snv/indel consensus                  #
  ########################################
  # TODO describe and test
  consensus:
    run: pcawg-consensus-calling-tool/consensus-calling.cwl
    in:
      variant_type:
      broad_input_file:
      dkfz_embl_input_file:
      muse_input_file:
      sanger_input_file:
      dbs_dir:
    out:
      consensus_zipped_vcf
      consensus_vcf_index

  ########################################
  # DKFZ Strand Bias Filter              #
  ########################################
  # TODO describe and test
  biasfilter:
    run: DKFZBiasFilter/Dockstore.cwl
    in: 
      write_qc:
      input_vcf:
      input_bam:
      input_bam_index:
      reference_sequence:
      reference_sequence_index:
    out:
      output_vcf_file
      output_qc_folder

