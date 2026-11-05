# shellcheck shell=bash
#
# What the AWS wizards of the API share (scripts/aws-first-deploy-wizard.sh and
# scripts/aws-after-first-deploy-wizard.sh): the production stack's names and
# the AWS, SSM and DNS helpers. Sourced after lib/wizard.sh, whose output
# helpers it uses.

# Used by the wizards that source this file.
# shellcheck disable=SC2034
REGION="us-east-1"
STACK="PlantaiApi"
SSM_PREFIX="/plantai/production"
API_DOMAIN="api.plantai.ia.br"
ZONE="plantai.ia.br"
export AWS_REGION="$REGION" AWS_DEFAULT_REGION="$REGION"

# Nothing goes to a .env: production values live in SSM and GitHub only.
ENV_FILE=/dev/null

# EMAIL_PATTERN: what the wizards accept as an e-mail address.
EMAIL_PATTERN='^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'

# ask_email VAR "Prompt": asks (visible) until VAR holds an e-mail address.
ask_email() {
  while [[ ! "${!1}" =~ $EMAIL_PATTERN ]]; do
    ask "$1" "$2"
  done
}

# require_tools TOOL...: stops the wizard when a TOOL is missing, or when the
# AWS CLI is not v2.
require_tools() {
  local tool
  for tool in "$@"; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      warn "$tool not found. Install it and run again."
      exit 1
    fi
  done
  if [[ "$(aws --version 2>&1)" != aws-cli/2* ]]; then
    warn "needs the AWS CLI v2 ($(aws --version 2>&1))."
    exit 1
  fi
}

# require_aws_identity: sets ACCOUNT and CALLER from the AWS CLI's credentials
# and shows them; stops the wizard when there are none.
require_aws_identity() {
  local identity
  if ! identity=$(aws sts get-caller-identity --query '[Account,Arn]' --output text 2>&1); then
    warn "the AWS CLI has no valid credentials: $identity"
    note "Sign in (aws configure sso / aws sso login, or AWS_PROFILE=...) and run again."
    exit 1
  fi
  ACCOUNT=${identity%%[[:space:]]*}
  CALLER=${identity##*[[:space:]]}
  printf '  %s✓ AWS%s  account %s, region %s\n' "$GREEN" "$RESET" "$ACCOUNT" "$REGION"
  note "         $CALLER"
}

# json_string VALUE: VALUE as a JSON string literal (builtins only, so the
# value never shows up in a process list). Control characters are refused.
json_string() {
  local value="$1"
  if [[ "$value" =~ [[:cntrl:]] ]]; then
    warn "the value has a control character (a line break?); paste it again."
    return 1
  fi
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  printf '"%s"' "$value"
}

# ssm_exists NAME: success when $SSM_PREFIX/NAME exists (value not read).
ssm_exists() {
  aws ssm get-parameter --name "$SSM_PREFIX/$1" --query Parameter.Name --output text >/dev/null 2>&1
}

# ssm_put NAME VALUE: writes the SecureString $SSM_PREFIX/NAME (overwriting).
# The request goes through stdin (--cli-input-json), never through argv. The
# description names the wizard that wrote it.
ssm_put() {
  local name="$1" value json
  value=$(json_string "$2") || return 1
  json=$(printf '{"Name":"%s","Type":"SecureString","Overwrite":true,"Description":"PlantAí API (scripts/%s)","Value":%s}' \
    "$SSM_PREFIX/$name" "$(basename "$0")" "$value")
  printf '%s' "$json" | aws ssm put-parameter --cli-input-json file:///dev/stdin >/dev/null
  printf '  %s✓ written%s %s/%s (SecureString)\n' "$GREEN" "$RESET" "$SSM_PREFIX" "$name"
}

# stack_status: the stack's status, or NONE when it does not exist.
stack_status() {
  aws cloudformation describe-stacks --stack-name "$STACK" \
    --query 'Stacks[0].StackStatus' --output text 2>/dev/null || echo NONE
}

# stack_output KEY: an output of the stack (empty when missing).
stack_output() {
  aws cloudformation describe-stacks --stack-name "$STACK" \
    --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" --output text 2>/dev/null || true
}

# stack_resource TYPE [LOGICAL_PREFIX]: physical id of the stack's first
# resource of TYPE whose logical id starts with LOGICAL_PREFIX (any, when
# omitted); empty when missing.
stack_resource() {
  local id
  id=$(aws cloudformation describe-stack-resources --stack-name "$STACK" \
    --query "StackResources[?ResourceType=='$1' && starts_with(LogicalResourceId, '${2:-}')].PhysicalResourceId | [0]" \
    --output text 2>/dev/null || true)
  [[ "$id" == "None" ]] && id=""
  printf '%s' "$id"
}

# dns_records NAME TYPE: the records of NAME as Google Public DNS sees them,
# one per line (TXT without quotes), so the check does not depend on the
# notebook's resolver cache.
dns_records() {
  curl -fsS "https://dns.google/resolve?name=$1&type=$2" 2>/dev/null \
    | grep -oE '"data": ?"([^"\\]|\\.)*"' | sed -E 's/^"data": ?"//; s/"$//; s/\\"//g' || true
}

# dns_cname NAME: the CNAME of NAME as Google Public DNS sees it (empty if none).
dns_cname() {
  dns_records "$1" CNAME | head -n1 || true
}
