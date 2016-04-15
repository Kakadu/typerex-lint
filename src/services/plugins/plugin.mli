type input

val mains : (string, (string * input list option) list) Hashtbl.t

module type SimpleConfig = sig
  type config_file
  type 'a option_class
  type 'a config_option
  val config : config_file
  val create_option :
    string list -> ?short_help:string -> string list -> ?level:int ->
    string -> string -> string
end

module MakePlugin :
  functor (Plugin : Plugin_types.PluginArg) ->
  sig
    module Config : SimpleConfig

    module MakeCheck :
      functor (CA : Check.CheckArg) ->
      sig
        val name : string
        val short_name : string
        val details : string
        val create_option :
          string ->
          string ->
          string ->
          string ->
          string

        module MakeWarnings :
          functor (WA : Warning.WarningArg) ->
          sig
            val report : Location.t -> WA.t -> unit
            val warnings : unit -> WA.t list
          end

      end

    module MakeInputAST :
      functor (A : Input.InputAST) ->
      sig
        val main : Parsetree.structure -> unit
      end

    module MakeInputCMT :
      functor (C : Input.InputCMT) ->
      sig
        val main : Cmt_format.cmt_infos -> unit
      end

    module MakeInputSRC :
      functor (S : Input.InputSRC) ->
      sig
        val main : string list -> unit
      end

    val name : string
    val short_name : string
    val details : string
  end
