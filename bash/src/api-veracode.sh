#!/bin/bash

# command line api

function veracode-app-builds {
    raw_xml=$(veracode-api-invoke-v4 getappbuilds)

    format-veracode-app-builds "$raw_xml"
}

function veracode-app-create {
    local appName="$1"
    raw_xml=$(veracode-api-invoke-v5 createapp app_name="$appName&business_criticality=Very+High")
    format-veracode-app-create "$raw_xml"
}

function veracode-app-delete {
    local id_or_name="$1"

    local raw_xml=$(veracode-api-invoke-v5 deleteapp app_id="$id_or_name")                               # try do delete as if $id_or_name is an id

    if [[ $raw_xml =~ .*\<error\>No.app_id.parameter.specified\</error\>.* ]] ; then            # if we get an <error>No app_id parameter specified</error> error message
        local app_id=$(veracode-app-id "$id_or_name")                                                 # try to resolve the name to an id
        raw_xml=$(veracode-api-invoke-v5 deleteapp app_id="$app_id")                               # try to delete is with the resolved id
    fi
    format-veracode-app-delete "$raw_xml"


}

function veracode-app-id {
    local app_Name=$1
    local data="$(veracode-api-invoke-v5 getapplist)"                                               # get data using curl
    get-value-from-string "$data" "$app_Name" 2                             # call get-value-from-string method
}

function veracode-app-id-create-if-required {
    local app_name=$1
    app_id=$(veracode-app-id "$app_name")                                   # try to get the id
    if [[ "$app_id" != "" ]]; then                                          # if we got a value back
        echo "$app_id"                                                      # it means it existed, so we just need to echo its value
    else                                                                    # if not, we need to created it
        veracode-create-app $app_name                                       # note:  veracode-create-app will echo the new app id

    fi
}

function veracode-app-info {
    local appId="$1"
    veracode-api-invoke-v5 getappinfo app_id="$appId"
}

function veracode-app-list {
    raw_xml=$(veracode-api-invoke-v5 getapplist)
    format-veracode-app-list "$raw_xml"
}

function veracode-app-names {
    raw_xml=$(veracode-api-invoke-v5 getapplist)
    format-veracode-app-names "$raw_xml"
}

function veracode-app-sandboxes {
    local appId="$1"
    veracode-api-invoke-v5 getsandboxlist app_id="$appId"
}


function veracode-app-build {
    local appId="$1"
    local sandboxId="$2"
    local version=`date "+%Y-%m-%d %T"`
    veracode-api-invoke-v5 createbuild app_id="$appId"&version="$version"
}

function veracode-app-build-in-sandbox {
    local appId="$1"
    local sandboxId="$2"
    local version=`date "+%Y-%m-%d %T"`
    veracode-api-invoke-v5 createbuild app_id="$appId"&version="$version"&sandbox_id="$sandboxId"
}

function veracode-app-build-begin-prescan {
    local appId="$1"
    raw_xml=$(veracode-api-invoke-v5 beginprescan "app_id=$appId&auto_scan=true&scan_all_nonfatal_top_level_modules=true")

    format-veracode-app-build-info "$raw_xml"
}

function veracode-app-build-begin-scan {
    local appId="$1"
    if [[ "$2" != "" ]]; then
        local target="modules=$2"
    else
        local target="scan_all_top_level_modules=true"
    fi

    #local all_modules="scan_all_top_level_modules=true"
    veracode-api-invoke-v5 beginscan "app_id=$appId&$target"
}

function veracode-app-build-delete {
    local appId="$1"
    veracode-api-invoke-v5 deletebuild "app_id=$appId"
}

function veracode-download {
    local app_name="$1"
    veracode-download-all-files $app_name
    veracode-scan-save-all_call-stacks $app_name
}

function veracode-download-all-files {
    local app_name="$1"
    local app_id=$(veracode-app-id "$app_name")
    local delete_if_download="$2"

    if [[ "$app_id" == "" ]]; then
        echo "Error: could not resolve app with name $app_name"
        echo
    else
        local build_info=$(veracode-api-invoke-v5 getbuildinfo "app_id=$app_id")
        local build_id=$(format-veracode-app-build-id "$build_info")

        echo "Downloading report files for: app_name = $app_name ; app_id = $app_id ; build_id  = $build_id"
        echo
        veracode-download-pdf-detailed  "$app_name" "$app_id" "$build_id"
        veracode-download-pdf-summary   "$app_name" "$app_id" "$build_id"
        veracode-download-xml-detailed  "$app_name" "$app_id" "$build_id"
        veracode-download-xml-summary   "$app_name" "$app_id" "$build_id"
        #veracode-download-pdf-3rd-party "$1"
        echo


        if [[ "$delete_if_download" == "true" ]]; then
            echo "Deleting application $app_name with $app_id"
            veracode-delete-app $app_id
        fi
    fi

}

function veracode-download-file {

    local command=$1
    local app_name="$2"
    local file_suffix="$3"
    local app_id="$4"
    local build_id="$5"

    local target_folder="./reports/${app_name}/$build_id"
    local target_file="$target_folder/$file_suffix"
    local latest_file="./reports/${app_name}/last_build_id"
    echo "     - $command to location $target_file"

    mkdir -p "$target_folder"
    veracode-api-download "2.0" "$command" "build_id=$build_id" "$target_file"

    if [[ $file_suffix =~ ".xml" ]]; then                                       # fix xml formatting
        echo "$(format-xml "$(cat  $target_file)")" > $target_file
    fi
    echo $build_id > $latest_file

}

function veracode-download-pdf-detailed  {     veracode-download-file detailedreportpdf    "$1" "detailed.pdf"  $2 $3 ; }
function veracode-download-pdf-summary   {     veracode-download-file summaryreportpdf     "$1" "summary.pdf"   $2 $3 ; }
function veracode-download-pdf-3rd-party {     veracode-download-file thirdpartyreportpdf  "$1" "3rd-party.pdf" $2 $3 ; }
function veracode-download-xml-detailed  {     veracode-download-file detailedreport       "$1" "detailed.xml"  $2 $3 ; }
function veracode-download-xml-summary   {     veracode-download-file summaryreport        "$1" "summary.xml"   $2 $3 ; }



function veracode-app-build-info {
    local appId="$1"
    raw_xml=$(veracode-api-invoke-v5 getbuildinfo "app_id=$appId")

    format-veracode-app-build-info "$raw_xml"
}


function veracode-app-build-files {
    local appId="$1"
    raw_xml=$(veracode-api-invoke-v5 getfilelist "app_id=$appId")
    veracode-format-file-list "$raw_xml"
}

function veracode-app-build-prescan-results {
    local appId="$1"
    veracode-api-invoke-v5 getprescanresults "app_id=$appId"
}

function veracode-app-build-status {
    local appId="$1"
    raw_xml=$(veracode-api-invoke-v5 getbuildinfo "app_id=$appId")

    local formatted_xml=$(format-xml "$raw_xml")
    status=$(attribute-value "$formatted_xml" "analysis_unit" "status")
    echo "$status"
}

function veracode-app-build-status-all {
    local all_apps=$(veracode-apps)
    # this should be in the veracode-format.sh but the results take some time to load so it is better to have it showing one line at the time
    echo "App id     App Name                       Scan status"
    echo -------------------------------------------------------------------
    for app_name in $all_apps;
    do
        local app_id=$(veracode-app-id "$app_name")
        if [[ "$app_id" != "" ]]; then
            local app_status=$(veracode-app-build-status $app_id)
            printf "%-10s %-30s %-30s \n" "$app_id" "$app_name" "$app_status"
        fi
    done
    echo
}

function veracode-app-upload-file {
    local appId="$1"
    local file="$2"
    raw_xml=$(veracode-api-invoke-v5-F uploadfile "app_id=$appId -F file=@$file")
    veracode-format-file-list "$raw_xml"
}


function veracode-scan-call-stack {
    local build_id="$1"
    local flaw_id="$2"
    echo "build_id=$build_id&flaw_id=$flaw_id"./
    raw_xml=$(veracode-api-invoke-v4 getcallstacks "build_id=$build_id&flaw_id=$flaw_id")
    echo "$(format-xml "$raw_xml")"
}

function veracode-scan-save-call-stack {
    local app_name="$1"
    local build_id=$(veracode-scan-last-build-id "$1")
    local flaw_id="$2"
    local raw_xml=$(veracode-scan-call-stack $build_id $flaw_id)

    if [[ $raw_xml =~ .*\<error\> ]]; then
        echo "Error downloading flaw with id $flaw_id: $raw_xml"
    else
        local target_folder=local target_folder="./reports/${app_name}/$build_id/call-stacks"
        local target_file="$target_folder/$flaw_id.xml"
        mkdir -p $target_folder
        echo "$(format-xml "$raw_xml")" > $target_file
        echo "     * saved call-stack with flaw_id $flaw_id to $target_file"
    fi
}

function veracode-scan-save-all_call-stacks {
    local app_name="$1"
    local total_flaws=$(veracode-scan-total-flaws $app_name)
    echo "Downloading call-stacks"
    echo
    if [[ "$total_flaws" == "0" ]]; then
        echo "  - no flaws to download"
    else
        echo "  - downloading $total_flaws call stacks from $app_name"
        for i in `seq 1 $total_flaws`;
        do
            veracode-scan-save-call-stack $app_name $i
        done
    fi
    echo
}

function veracode-scan-last-build-id {
    local app_name="$1"
    local target_folder="./reports/${app_name}/$build_id"
    local latest_file="./reports/${app_name}/last_build_id"
    echo $(cat $latest_file)
}

function veracode-scan-total-flaws {
    local app_name="$1"
    local target_folder="./reports/${app_name}/$build_id"
    local latest_file="./reports/${app_name}/last_build_id"
    local last_build_id=$(cat $latest_file)
    local summary_xml="./reports/${app_name}/$last_build_id/summary.xml"

    local raw_xml="$(cat $summary_xml)"

    echo $(attribute-value "$raw_xml" "summaryreport" "total_flaws")

}
# similar methods with different signatures (the idea is to make the method name as intuitive as possible)

function veracode-apps         { veracode-app-names               ; }
function veracode-builds       { veracode-app-builds              ; }
function veracode-create-app   { veracode-app-create            $1; }
function veracode-delete-app   { veracode-app-delete            $1; }
function veracode-delete-build { veracode-app-build-delete      $1; }
function veracode-list         { veracode-app-list                ; }
function veracode-status       { veracode-app-build-status      $1; }
function veracode-status-all   { veracode-app-build-status-all    ; }

