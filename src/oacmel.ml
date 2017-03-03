open Cmdliner
open Lwt

(* XXX. Actually, this is not really a "default".
 * - letsencrypt wants you to accept the terms of agreement,
 *   but the url for these is on a non-standard endpoint /terms
 *)
let default_directory_url = "https://acme-v01.api.letsencrypt.org/directory"
(* let default_directory_url = "https://acme-staging.api.letsencrypt.org/directory" *)


(* XXX. Perhaps there's a more decent way in OCaml for reading a file? *)
(* XXX. we are not dealing with exceptions here. *)
let read_file filename =
  let bufsize = 32768 in
  let ic = open_in filename in
  let ret = Bytes.make bufsize '\000' in
  input ic ret 0 bufsize |> ignore;
  ret

let directory_url_arg =
  let doc = "ACME directory URL" in
  Arg.(value & opt string default_directory_url & info ["directory-url"] ~docv:"URL" ~doc)

let rsa_pem_arg =
  let doc = "File containing the PEM-encoded RSA private key." in
  Arg.(value & opt string "priv.key" & info ["account-key"] ~docv:"FILE" ~doc)

let csr_pem_arg =
  let doc = "File containing the PEM-encoded CSR." in
  Arg.(value & opt string "certificate.csr" & info ["csr"] ~docv:"FILE" ~doc)

let acme_dir_arg =
  let default_path = "/var/www/html/.well-known/acme-challenge/" in
  let doc =
    "Base path for where to write challenges. " ^
    "For letsencrypt, it must be the one serving " ^
    "http://example.com/.well-known/acme-challenge/" in
  Arg.(value & opt string default_path & info ["acme_dir"] ~docv:"DIR" ~doc)

(* XXX. the information for all domains is already available in the csr,
 * there should be no need to have it as parameter.
 * However, the X509  doesn't export an API for this. *)
let domain_arg =
  (* XXX. please remove me *)
  let default_host = "test.tumbolandia.net" in
  let doc = "The domain to validate." in
  (* XXX. this should be an uri, non optional, from which we take only the host *)
  Arg.(value & opt string default_host & info ["H"; "host"] ~docv:"URL" ~doc)

let debug_arg =
  let doc = "Turn on debug logging." in
  Arg.(value & flag & info ["v"] ~doc)

let main directory_url rsa_pem csr_pem acme_dir domain debug =
  let log_level = if debug then Logs.Debug else Logs.Info in
  let rsa_pem = read_file rsa_pem in
  let csr_pem = read_file csr_pem in
  let f =
    Acme.Client.get_crt directory_url rsa_pem csr_pem acme_dir domain
  in
  Logs.set_level (Some log_level);
  Logs.set_reporter (Logs_fmt.reporter ());
  match Lwt_main.run f with
  | Error e ->
     Logs.err (fun m -> m "Error: %s" e)
  | Ok pem ->
     Logs.info (fun m -> m "Certificate downloaded");
     print_endline pem

let info =
  let doc = "just another ACME client" in
  let man = [
      `S "DESCRIPTION"; `P "This is software is experimental. Don't use it.";
      `S "BUGS"; `P "Email bug reports to <maker@tumbolandia.net>";
    ] in
  Term.info "oacmel" ~version:"0.1" ~doc ~man

let () =
  let cli = Term.(const main
                  $ directory_url_arg
                  $ rsa_pem_arg
                  $ csr_pem_arg
                  $ acme_dir_arg
                  $ domain_arg
                  $ debug_arg) in
  match Term.eval (cli, info) with
  | `Error _ -> exit 1
  | _        -> exit 0
