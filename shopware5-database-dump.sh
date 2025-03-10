#!/usr/bin/env bash
set -o nounset
set -o errexit
set -o errtrace
set -o pipefail
IFS=$'\n\t'

###############################################################################
# Environment
###############################################################################

_ME="$(basename "${0}")"

###############################################################################
# Debug
###############################################################################

# _debug()
#
# Usage:
#   _debug <command> <options>...
#
# Description:
#   Execute a command and print to standard error. The command is expected to
#   print a message and should typically be either `echo`, `printf`, or `cat`.
#
# Example:
#   _debug printf "Debug info. Variable: %s\\n" "$0"
__DEBUG_COUNTER=0
_debug() {
  if ((${_USE_DEBUG:-0}))
  then
    __DEBUG_COUNTER=$((__DEBUG_COUNTER+1))
    {
      # Prefix debug message with "bug (U+1F41B)"
      printf "🐛  %s " "${__DEBUG_COUNTER}"
      "${@}"
      printf "―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――\\n"
    } 1>&2
  fi
}

###############################################################################
# Error Messages
###############################################################################

_exit_1() {
  {
    printf "%s " "$(tput setaf 1)!$(tput sgr0)"
    "${@}"
  } 1>&2
  exit 1
}
_warn() {
  {
    printf "%s " "$(tput setaf 1)!$(tput sgr0)"
    "${@}"
  } 1>&2
}

###############################################################################
# Help
###############################################################################

_print_help() {
  cat <<HEREDOC
Dumps a Shopware 5 database with a bit of cleanup and a GDPR mode ignoring sensitive data.

Usage:
  ${_ME} [filename.sql] --database db_name --user username [--host 127.0.0.1] [--port 3306] [--gdpr]
  ${_ME} [filename.sql] -d db_name -u username [-H 127.0.0.1] [-p 3306] [--gdpr]
  ${_ME} -h | --help

Arguments:
  filename.sql   Set output filename, will be gzipped, dump.sql by default

Options:
  -h --help      Display this help information.
  -d --database  Set database name
  -u --user      Set database user name
  -H --host      Set hostname for database server (default: 127.0.0.1)
  -p --port      Set database server port (default: 3306)
  --gdpr         Enable GDPR data filtering
HEREDOC
}

###############################################################################
# Options
###############################################################################

# Parse Options ###############################################################

# Initialize program option variables.
_PRINT_HELP=0
_USE_DEBUG=0

# Initialize additional expected option variables.
_OPTION_GDPR=0
_DATABASE=
_HOST=127.0.0.1
_PORT=3306
_USER=

__get_option_value() {
  local __arg="${1:-}"
  local __val="${2:-}"

  if [[ -n "${__val:-}" ]] && [[ ! "${__val:-}" =~ ^- ]]
  then
    printf "%s\\n" "${__val}"
  else
    _exit_1 printf "%s requires a valid argument.\\n" "${__arg}"
  fi
}

while ((${#}))
do
  __arg="${1:-}"
  __val="${2:-}"

  case "${__arg}" in
    -h|--help)
      _PRINT_HELP=1
      ;;
    --debug)
      _USE_DEBUG=1
      ;;
    --gdpr)
      _OPTION_GDPR=1
      ;;
    -d|--database)
      _DATABASE="$(__get_option_value "${__arg}" "${__val:-}")"
      shift
      ;;
    -u|--user)
      _USER="$(__get_option_value "${__arg}" "${__val:-}")"
      shift
      ;;
    -H|--host)
      _HOST="$(__get_option_value "${__arg}" "${__val:-}")"
      shift
      ;;
    -p|--port)
      _PORT="$(__get_option_value "${__arg}" "${__val:-}")"
      shift
      ;;
    --endopts)
      # Terminate option parsing.
      break
      ;;
    -*)
      _exit_1 printf "Unexpected option: %s\\n" "${__arg}"
      ;;
  esac

  shift
done

###############################################################################
# Program Functions
###############################################################################

_dump() {
  _FILENAME=${1:-dump.sql}

  printf ">> Creating structure dump...\\n"

  _COLUMN_STATISTICS=
  if mysqldump --help | grep "\-\-column-statistics" > /dev/null; then
    _COLUMN_STATISTICS="--column-statistics=0"
  fi

  mysqldump ${_COLUMN_STATISTICS} --no-tablespaces --quick -C --hex-blob --single-transaction --no-data --skip-routines --host=${_HOST} --port=${_PORT} --user=${_USER} -p ${_DATABASE} \
  | LANG=C LC_CTYPE=C LC_ALL=C sed -e 's/DEFINER[ ]*=[ ]*[^*]*\*/\*/' \
  | LANG=C LC_CTYPE=C LC_ALL=C sed -e '/^ALTER DATABASE/d' \
  > ${_FILENAME}

  _IGNORED_TABLES=()

  if ((_OPTION_GDPR))
  then
    printf ">> Remove GDPR-relevant data\\n"
    _IGNORED_TABLES=(
      # Customer related tables
      s_user
      s_user_addresses
      s_user_attributes
      s_user_billingaddress
      s_user_shippingaddress
      s_core_payment_data
      s_core_payment_instance
      
      # Order related tables
      s_order
      s_order_attributes
      s_order_basket
      s_order_basket_attributes
      s_order_billingaddress
      s_order_billingaddress_attributes
      s_order_details
      s_order_details_attributes
      s_order_shippingaddress
      s_order_shippingaddress_attributes
      s_order_notes
      
      # Checkout and cart tables
      s_order_basket
      s_order_basket_attributes
      s_user_basket
      s_user_basket_attributes
      
      # Newsletter and marketing
      s_campaigns_mailaddresses
      s_campaigns_maildata
      s_campaigns_logs
      s_core_optin
      
      # User session data
      s_core_sessions
      s_core_sessions_backend
      
      # Search statistics
      s_statistics_search
      s_statistics_currentusers
      s_statistics_pool
      s_statistics_referer
      s_statistics_visitors
      
      # User recovery and authentication
      s_core_auth
      s_core_auth_attributes
      s_core_auth_roles
      s_core_acl_roles
      s_core_acl_privileges
      s_user_passwordchange
      
      # Review tables
      s_articles_vote
      s_articles_vote_attributes
      
      # Log tables
      s_core_log
      s_adodb_logsql
      s_emarketing_lastarticles
      s_emarketing_tellafriend
      s_mail_log
      s_mail_log_contact
      s_mail_log_recipient
      
      # Plugin specific tables that might contain personal data
      s_plugin_paypal_installments_order
      s_plugin_paypal_installments_order_position
      s_plugin_paypal_installments_order_tax
      s_plugin_swag_visitor_customers_baskets_attributes
      s_plugin_mailcatcher
      s_plugin_mailcatcher_attachments
      s_plugin_byjuno_transactions
      shopsy_mahnung_history
      
      # Customer search and streams
      s_customer_search_index
      s_customer_streams_mapping
      
      # Payment related personal data
      swag_payment_paypal_unified_payment_instruction
      postfinancecw_transaction
      postfinancecw_customer_context
      
      # Statistics and tracking
      s_statistics_article_impression
      s_emarketing_partner
      s_emarketing_partner_attributes
      s_emarketing_referer
      
      # Document related personal data
      s_order_documents
      s_order_documents_attributes
      
      # ESD and downloads (might contain personal data)
      s_articles_esd_serials
      s_order_esd
      
      # Additional customer related data
      s_order_comparisons
      s_order_basket_signatures
      s_order_history
    )
  fi

  _IGNORED_TABLES+=('s_search_index')
  _IGNORED_TABLES+=('s_search_keywords')
  _IGNORED_TABLES+=('s_core_sessions')
  _IGNORED_TABLES+=('s_core_sessions_backend')

  _IGNORED_TABLES_ARGUMENTS=()
  for _TABLE in "${_IGNORED_TABLES[@]}"
  do :
     _IGNORED_TABLES_ARGUMENTS+=("--ignore-table=${_DATABASE}.${_TABLE}")
  done

  printf ">> Creating data dump...\\n"

  mysqldump ${_COLUMN_STATISTICS} --no-tablespaces --no-create-info --skip-triggers --quick -C --hex-blob --single-transaction --skip-routines --host=${_HOST} --port=${_PORT} --user=${_USER} -p "${_IGNORED_TABLES_ARGUMENTS[@]}" ${_DATABASE} \
    | LANG=C LC_CTYPE=C LC_ALL=C sed -e 's/DEFINER[ ]*=[ ]*[^*]*\*/\*/' \
    | LANG=C LC_CTYPE=C LC_ALL=C sed -e '/^ALTER DATABASE/d' \
    >> ${_FILENAME}

  printf ">> Gzipping dump...\\n"
  gzip ${_FILENAME}

  printf ">> Dump created\\n"
}

###############################################################################
# Main
###############################################################################

_main() {
  if ((_PRINT_HELP)) || [[ -z ${_DATABASE} ]]
  then
    _print_help
  else
    _dump "$@"
  fi
}

_main "$@"