set_prop() {

  local restartDaemon=false

  case ${1-} in

    # set multiple properties
    *=*)
      . $defaultConfig
      . $config

      export "$@"

      [ .${mcc-${max_charging_current-x}} = .x ] \
        || set_ch_curr ${mcc:-${max_charging_current:--}} || :

      [ ".${mcv-${max_charging_voltage-x}}" = .x ] || {
        set_ch_volt "${mcv:-${max_charging_voltage:--}}" || :
      }
    ;;

    # reset config
    r|--reset)
      ! daemon_ctrl stop > /dev/null || restartDaemon=true
      cat $defaultConfig > $config
      print_config_reset
      ! $restartDaemon || $TMPDIR/accd --init $config
      return 0
    ;;

    # print default config
    d|--print-default)
      . $defaultConfig
      . $execDir/print-config.sh | { grep -E "${2-.}" | more; } || :
      return 0
    ;;

    # print current config
    p|--print)
      . $execDir/print-config.sh | { grep -E "${2-.}" | more; } || :
      return 0
    ;;

    # set charging switch
    s|--charging*witch)
      IFS=$'\n'
      PS3="$(print_choice_prompt)"
      print_known_switches
      . $execDir/select.sh
      select_ charging_switch $(print_auto; cat $TMPDIR/ch-switches; ! grep -q / $TMPDIR/ch-curr-ctrl-files 2>/dev/null || printf '0 mA\n250 mA\n350 mA\n500 mA\n'; ! grep -q / $TMPDIR/ch-volt-ctrl-files 2>/dev/null || printf '3700 mV\n'; print_exit)
      [ ${charging_switch:-x} != $(print_exit) ] || exit 0
      [ ${charging_switch:-x} != $(print_auto) ] || charging_switch=
      case "${charging_switch:-x}" in
        "$(print_exit)") exit 0;;
        "$(print_auto)") charging_switch=;;
        */*)
          case "$charging_switch" in
            */*) charging_switch="$charging_switch --";;
          esac
        ;;
      esac
      unset IFS
    ;;

    # print switches
    s:|--charging*witch:)
      cat $TMPDIR/ch-switches
      ! grep -q / $TMPDIR/ch-curr-ctrl-files 2>/dev/null || printf '0 mA\n250 mA\n350 mA\n500 mA\n'
      ! grep -q / $TMPDIR/ch-volt-ctrl-files 2>/dev/null || printf '3700 mV\n'
      return 0
    ;;

    # set charging current
    c|--current)
      set_ch_curr ${2-}
    ;;

    # set charging voltage
    v|--voltage)
      shift
      set_ch_volt "$@"
    ;;

    # set language
    l|--lang)
      IFS=$'\n'
      PS3="$(print_choice_prompt)"
      . $execDir/select.sh
      eval 'select_ _lang \
        $(echo "- English (en)" | grep -v $language; \
        (for file in $(ls -1 $execDir/translations/*/strings.sh); do \
          sed -n "'s/# /- /p'" $file | grep -v $language; \
        done); \
        print_exit)'
      lang=${_lang#*\(}
      [ $lang != $(print_exit) ] || exit 0
      lang=${lang%\)*}
      unset IFS
    ;;

    # print current config (full)
    *)
      . $execDir/print-config.sh | more
      return 0
    ;;

  esac

  # check whether a daemon restart is required (to restore defaults)
  if { [ ".${chargingSwitch[0]-x}" != .x ] \
    && [ ".${s-${charging_switch-x}}" != .x ]; } \
    || [ ".${cw-${current_workaround-x}}" != .x ]
  then
    ! daemon_ctrl stop || restartDaemon=true
  fi > /dev/null

  # update config.txt
  . $execDir/write-config.sh

  if $restartDaemon; then
    if [ ".${cw-${current_workaround-x}}" != .x ]; then
      $TMPDIR/accd --init $config
    else
      $TMPDIR/accd $config
    fi
  fi
}
