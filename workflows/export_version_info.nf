// modules
include { GET_DOCKER_INFO as QC_DOCKER_INFO } from "../nf-submodules/modules/qc_report.nf"
include { GET_DOCKER_INFO as PDC_DOCKER_INFO } from "../nf-submodules/modules/pdc.nf"
include { GET_VERSION as ENCYCLOPEDIA_VERSION } from "../nf-submodules/modules/encyclopedia.nf"
include { GET_VERSION as PROTEOWIZARD_VERSIONS } from "../nf-submodules/modules/skyline.nf"

process WRITE_VERSION_INFO {
    publishDir "${params.result_dir}/", failOnError: true, mode: 'copy'
    container 'mauraisa/aws_bash:0.5'

    input:
        val workflow_var_names
        val workflow_values
        path qc_info_file
        path pdc_info_file
        path encyclopedia_info_file
        path proteowizard_info_file

    output:
        path("DIA_CDAP_versions.txt")

    shell:
        '''
        parse_info_file() {
            local file_path=$1
            local -n array=$2

            while IFS='=' read -r key value || [ -n "$key" ]; do
                array["$key"]="$value"
            done < "$file_path"
        }

        declare -A qc_info
        parse_info_file '!{qc_info_file}' qc_info

        declare -A pdc_info
        parse_info_file '!{pdc_info_file}' pdc_info

        declare -A encyclopedia_info
        parse_info_file '!{encyclopedia_info_file}' encyclopedia_info

        declare -A proteowizard_info
        parse_info_file '!{proteowizard_info_file}' proteowizard_info

        workflow_var_names=( \
            '!{workflow_var_names.join("' '")}' \
            'Msconvert version' \
            'Skyline version' \
            'EncyclopeDIA version' \
            'pdc_client docker image' \
            'pdc_client git repo' \
            'dia_qc_report docker image' \
            'dia_qc_report git repo' \
        )
        workflow_values=( \
            '!{workflow_values.join("' '")}' \
            "${proteowizard_info[msconvert_version]}" \
            "${proteowizard_info[skyline_version]}" \
            "${encyclopedia_info[encyclopedia_version]}" \
            "${pdc_info[DOCKER_IMAGE]}:${pdc_info[DOCKER_TAG]}" \
            "${pdc_info[GIT_REPO]}/tree/${pdc_info[GIT_BRANCH]} [${pdc_info[GIT_SHORT_HASH]}]" \
            "${qc_info[DOCKER_IMAGE]}:${qc_info[DOCKER_TAG]}" \
            "${qc_info[GIT_REPO]}/tree/${qc_info[GIT_BRANCH]} [${qc_info[GIT_SHORT_HASH]}]" \
        )

        for i in ${!workflow_var_names[@]} ; do
            if [ i -eq 0 ] ; then
                echo "${workflow_var_names[$i]}: ${workflow_values[$i]}" > DIA_CDAP_versions.txt
            else
                echo "${workflow_var_names[$i]}: ${workflow_values[$i]}" >> DIA_CDAP_versions.txt
            fi
        done
        '''
}

workflow export_version_info {

    take:
        fasta
        spectral_library
        mzml_files

    main:
        PDC_DOCKER_INFO()
        QC_DOCKER_INFO()
        PROTEOWIZARD_VERSIONS()
        ENCYCLOPEDIA_VERSION()

        workflow_vars = ['Workflow git info': "${workflow.repository} - ${workflow.revision} [${workflow.commitId}]",
                         'Workflow cmd': workflow.commandLine]

        version_vars = Channel.fromList(workflow_vars.collect{k, v -> tuple(k, v)}).concat(
                mzml_files.map{ f -> tuple("Spectra File", f.getName()) }
            ).concat(
                spectral_library.map{ f -> tuple("Spectral library", file(f).name)},
                fasta.map{ f -> tuple("Fasta file", file(f).name)}

            )

        var_names = version_vars.map{ it[0] }
        var_values = version_vars.map{ it[1] }

        WRITE_VERSION_INFO(var_names.collect(),
                           var_values.collect(),
                           QC_DOCKER_INFO.out.info_file,
                           PDC_DOCKER_INFO.out.info_file,
                           ENCYCLOPEDIA_VERSION.out.info_file,
                           PROTEOWIZARD_VERSIONS.out.info_file)
}

