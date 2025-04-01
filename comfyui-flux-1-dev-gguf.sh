#!/bin/bash


# -------------------------------------------------------------------------------------------------
# Provisions a ComfyUI setup with FLUX.1-dev and GGUF support.

# Template
# https://cloud.vast.ai?ref_id=62897&template_id=f3a02e882f1644b8fac2327d195061cc

# Setup
# Set environment variables in your vast account prior to creating your instance.
# - HF_TOKEN: Hugging Face token for downloading models from Hugging Face.
# - CIVITAI_TOKEN: Civitai token for downloading models from Civitai.
# Create a personal template based on the link above and replace the provisioning script.
# - PROVISIONING_SCRIPT: https://raw.githubusercontent.com/nheinrich/vast-provisioning/refs/heads/main/comfyui-flux-1-dev-gguf.sh
# Github caches raw files for 5 minutes so if you make changes wait for the cache to clear.
# The template may need to be re-saved after this script is updated, it doesn't always seem to update.
# The template takes up ~25GB of space, partition accordingly.

# Next
# [ ] Integrate AWS CLI (using env vars) so I can easily offload output or models to S3.
# [ ] Replace the default workflow with a custom one.
# [ ] Add cheatsheet (post-setup reminders, alias overview, hf dls, command explanations, s3 transfers)

# Instructions
# 1. Create a new instance using the template.
# 2. Open the instance in your browser.
# 3. Open ComfyUI in your browser.
# 4. The default workflow won't work as we didn't download the models for it.
# 5. Load a workflow from the workflows folder in the sidebar.
# 6. Cook!

# Reference
# https://docs.vast.ai/creating-a-custom-template#JqM6i


# -------------------------------------------------------------------------------------------------
# Activate the Python virtual environment

source /venv/main/bin/activate
COMFYUI_DIR=${WORKSPACE}/ComfyUI


# -------------------------------------------------------------------------------------------------
# Packages and models to install

APT_PACKAGES=(
  "tree"
)

PIP_PACKAGES=(
  "civitdl"
  "huggingface-hub[cli]"
)

NODES=(
  "https://github.com/ltdrdata/ComfyUI-Manager"
  "https://github.com/crystian/ComfyUI-Crystools"
  "https://github.com/yolain/ComfyUI-Easy-Use"
  "https://github.com/rgthree/rgthree-comfy"
  "https://github.com/city96/ComfyUI-GGUF"
  "https://github.com/Fannovel16/comfyui_controlnet_aux"
  "https://github.com/gseth/ControlAltAI-Nodes"
  "https://github.com/sipherxyz/comfyui-art-venture"
  "https://github.com/kijai/ComfyUI-Florence2"
)

WORKFLOWS=(
  "https://raw.githubusercontent.com/nheinrich/comfyui-workflows/refs/heads/main/flux/flux-v1-dev-gguf.json"
  "https://raw.githubusercontent.com/nheinrich/comfyui-workflows/refs/heads/main/flux/flux-img-control-net-union.json"
  "https://raw.githubusercontent.com/nheinrich/comfyui-workflows/refs/heads/main/flux/flux-img-upscale-basic.json"
  "https://raw.githubusercontent.com/nheinrich/comfyui-workflows/refs/heads/main/flux/flux-img-upscale.json"
  "https://raw.githubusercontent.com/nheinrich/comfyui-workflows/refs/heads/main/flux/flux-img2txt2img.json"
)

CHECKPOINT_MODELS=(
)

CLIP_MODELS=(
  "https://huggingface.co/city96/t5-v1_1-xxl-encoder-gguf/resolve/main/t5-v1_1-xxl-encoder-Q8_0.gguf"
  "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors"
)

CONTROLNET_MODELS=(
  https://huggingface.co/Shakker-Labs/FLUX.1-dev-ControlNet-Union-Pro/resolve/main/diffusion_pytorch_model.safetensors
)

LORA_MODELS=(
)

UNET_MODELS=(
  "https://huggingface.co/city96/FLUX.1-dev-gguf/resolve/main/flux1-dev-Q8_0.gguf"
)

UPSCALE_MODELS=(
  "https://huggingface.co/gemasai/4x_NMKD-Siax_200k/resolve/main/4x_NMKD-Siax_200k.pth"
  "https://huggingface.co/Kim2091/AnimeSharp/resolve/main/4x-AnimeSharp.pth"
  "https://huggingface.co/FacehugmanIII/4x_foolhardy_Remacri/resolve/main/4x_foolhardy_Remacri.pth"
)

VAE_MODELS=(
  "https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/ae.safetensors"
)

# -----------------------------------------------------------------------------
# Vast

function provisioning_start() {
  provisioning_print_header

  if provisioning_has_valid_hf_token; then
    provisioning_get_apt_packages
    provisioning_get_nodes
    provisioning_get_pip_packages
    provisioning_get_comfyui_packages
    provisioning_get_aws_cli
    provisioning_create_aliases
    provisioning_print_end
  else
    printf "\nHugging Face: invalid token, set the HF_TOKEN environment variable and try again.\n"
  fi
}

# -----

function provisioning_print_header() {
  printf "\n##############################################\n#                                            #\n#          Provisioning container            #\n#                                            #\n#         This will take some time           #\n#                                            #\n# Your container will be ready on completion #\n#                                            #\n##############################################\n\n"
}

function provisioning_print_end() {
  printf "\nProvisioning complete:  Application will start now\n\n"
}

# -----

function provisioning_get_apt_packages() {
  if [[ -n $APT_PACKAGES ]]; then
    sudo $APT_INSTALL ${APT_PACKAGES[@]}
  fi
}

function provisioning_get_nodes() {
  printf "\nDownloading custom nodes...\n"
  for repo in "${NODES[@]}"; do
    dir="${repo##*/}"
    path="${COMFYUI_DIR}/custom_nodes/${dir}"
    requirements="${path}/requirements.txt"
    if [[ -d $path ]]; then
      if [[ ${AUTO_UPDATE,,} != "false" ]]; then
        printf "Updating node: %s...\n" "${repo}"
        ( cd "$path" && git pull )
        if [[ -e $requirements ]]; then
          pip install --no-cache-dir -r "$requirements"
        fi
      fi
    else
      printf "Downloading node: %s...\n" "${repo}"
      git clone "${repo}" "${path}" --recursive
      if [[ -e $requirements ]]; then
        pip install --no-cache-dir -r "${requirements}"
      fi
    fi
  done
}

function provisioning_get_pip_packages() {
  if [[ -n $PIP_PACKAGES ]]; then
    pip install --no-cache-dir ${PIP_PACKAGES[@]}
  fi
}

function provisioning_get_comfyui_packages() {
  # Workflows
  printf "\nDownloading workflows...\n"
  workflows_dir="${COMFYUI_DIR}/user/default/workflows"
  mkdir -p "${workflows_dir}"
  provisioning_get_files \
    "${workflows_dir}" \
    "${WORKFLOWS[@]}"

  # Checkpoints
  printf "\nDownloading checkpoints...\n"
  provisioning_get_files \
    "${COMFYUI_DIR}/models/checkpoints" \
    "${CHECKPOINT_MODELS[@]}"

  # Clips
  printf "\nDownloading clips...\n"
  provisioning_get_files \
    "${COMFYUI_DIR}/models/clip" \
    "${CLIP_MODELS[@]}"

  # Controlnets
  printf "\nDownloading controlnets...\n"
  provisioning_get_files \
    "${COMFYUI_DIR}/models/controlnet" \
    "${CONTROLNET_MODELS[@]}"

  # Loras
  printf "\nDownloading loras...\n"
  provisioning_get_files \
    "${COMFYUI_DIR}/models/loras" \
    "${LORA_MODELS[@]}"

  # Unets
  printf "\nDownloading unets...\n"
  provisioning_get_files \
    "${COMFYUI_DIR}/models/unet" \
    "${UNET_MODELS[@]}"

  # Upscale models
  printf "\nDownloading upscale models...\n"
  upscale_models_dir="${COMFYUI_DIR}/models/upscale_models"
  mkdir -p "${upscale_models_dir}"
  provisioning_get_files \
    "${COMFYUI_DIR}/models/upscale_models" \
    "${UPSCALE_MODELS[@]}"

  # VAE models
  printf "\nDownloading vaes...\n"
  provisioning_get_files \
    "${COMFYUI_DIR}/models/vae" \
    "${VAE_MODELS[@]}"
}

function provisioning_get_files() {
    if [[ -z $2 ]]; then return 1; fi

    dir="$1"
    mkdir -p "$dir"
    shift
    arr=("$@")
    printf "Downloading %s model(s) to %s...\n" "${#arr[@]}" "$dir"
    for url in "${arr[@]}"; do
        printf "Downloading: %s\n" "${url}"
        provisioning_download "${url}" "${dir}"
        printf "\n"
    done
}

function provisioning_has_valid_hf_token() {
    [[ -n "$HF_TOKEN" ]] || return 1
    url="https://huggingface.co/api/whoami-v2"

    response=$(curl -o /dev/null -s -w "%{http_code}" -X GET "$url" \
        -H "Authorization: Bearer $HF_TOKEN" \
        -H "Content-Type: application/json")

    # Check if the token is valid
    if [ "$response" -eq 200 ]; then
        return 0
    else
        return 1
    fi
}

function provisioning_has_valid_civitai_token() {
    [[ -n "$CIVITAI_TOKEN" ]] || return 1
    url="https://civitai.com/api/v1/models?hidden=1&limit=1"

    response=$(curl -o /dev/null -s -w "%{http_code}" -X GET "$url" \
        -H "Authorization: Bearer $CIVITAI_TOKEN" \
        -H "Content-Type: application/json")

    # Check if the token is valid
    if [ "$response" -eq 200 ]; then
        return 0
    else
        return 1
    fi
}

# Download from $1 URL to $2 file path
function provisioning_download() {
    if [[ -n $HF_TOKEN && $1 =~ ^https://([a-zA-Z0-9_-]+\.)?huggingface\.co(/|$|\?) ]]; then
        auth_token="$HF_TOKEN"
    elif
        [[ -n $CIVITAI_TOKEN && $1 =~ ^https://([a-zA-Z0-9_-]+\.)?civitai\.com(/|$|\?) ]]; then
        auth_token="$CIVITAI_TOKEN"
    fi
    if [[ -n $auth_token ]];then
        wget --header="Authorization: Bearer $auth_token" -qnc --content-disposition --show-progress -e dotbytes="${3:-4M}" -P "$2" "$1"
    else
        wget -qnc --content-disposition --show-progress -e dotbytes="${3:-4M}" -P "$2" "$1"
    fi
}

# -------------------------------------------------------------------------------------------------
# Custom

function provisioning_get_aws_cli() {
  printf "\nDownloading AWS CLI...\n"
  mkdir -p /workspace/aws
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/workspace/aws/awscliv2.zip"
  unzip /workspace/aws/awscliv2.zip
  /workspace/aws/install
  printf "\nAWS CLI installed successfully, ready for configuration.\n"
}

function provisioning_create_aliases() {
  printf "\nCreating aliases...\n"

  aliases="
    # Custom aliases
    alias ..='cd ..'
    alias ...='cd ../..'
    alias ....='cd ../../..'
    alias ls='ls -laF --color=auto'
    alias comfy='cd /workspace/ComfyUI/; ls'
    alias nodes='cd /workspace/ComfyUI/custom_nodes; ls'
    alias outputs='cd /workspace/ComfyUI/output; ls'
    alias models='cd /workspace/ComfyUI/models; ls'
    alias checkpoints='cd /workspace/ComfyUI/models/checkpoints; ls'
    alias clips='cd /workspace/ComfyUI/models/clip; ls'
    alias controlnets='cd /workspace/ComfyUI/models/controlnet; ls'
    alias loras='cd /workspace/ComfyUI/models/loras; ls'
    alias unets='cd /workspace/ComfyUI/models/unet; ls'
    alias upscales='cd /workspace/ComfyUI/models/upscale_models; ls'
    alias vaes='cd /workspace/ComfyUI/models/vae; ls'
    alias xoutput='rm -rf /workspace/ComfyUI/output/* && echo \"Cleared all output in /workspace/ComfyUI/output/\" && ls /workspace/ComfyUI/output/'
  "

  echo "$aliases" >> ~/.bashrc
  source ~/.bashrc
}


# -------------------------------------------------------------------------------------------------

# Allow user to disable provisioning if they started with a script they didn't want
if [[ ! -f /.noprovisioning ]]; then
  provisioning_start
fi
