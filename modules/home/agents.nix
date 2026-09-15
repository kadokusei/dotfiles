{ config, pkgs, lib, ... }:

let
  # dot_codex/modify_private_config.toml と同一の11キー。ローカルキーは保持される
  codexSharedKeys = ''
    .model = "gpt-6-astra"
    | .model_reasoning_effort = "medium"
    | .default_subagent_model = "gpt-5.6-luna"
    | .default_subagent_reasoning_effort = "max"
    | .service_tier = "default"
    | .approvals_reviewer = "auto_review"
    | .approval_policy = "on-request"
    | .sandbox_mode = "workspace-write"
    | .features.context_management.experimental_mode = true
    | .marketplaces.ponytail.source_type = "git"
    | .marketplaces.ponytail.source = "https://github.com/DietrichGebert/ponytail.git"
    | .plugins."ponytail@ponytail".enabled = true'';
in
{
  home.file.".agents/AGENTS.md".source = ../../config/agents/AGENTS.md;

  home.file.".codex/AGENTS.md".text = builtins.readFile ../../config/agents/AGENTS.md + ''

    # Codex-specific instructions

    <!-- context7 -->
    Use the `ctx7` CLI to fetch current documentation whenever the user asks about a library, framework, SDK, API, CLI tool, or cloud service -- even well-known ones like React, Next.js, Prisma, Express, Tailwind, Django, or Spring Boot. This includes API syntax, configuration, version migration, library-specific debugging, setup instructions, and CLI tool usage. Use even when you think you know the answer -- your training data may not reflect recent changes. Prefer this over web search for library docs.

    Do not use for: refactoring, writing scripts from scratch, debugging business logic, code review, or general programming concepts.

    ## Steps

    1. Resolve library: `npx ctx7@latest library <name> "<user's question>"` — use the official library name with proper punctuation (e.g., "Next.js" not "nextjs", "Customer.io" not "customerio", "Three.js" not "threejs")
    2. Pick the best match (ID format: `/org/project`) by: exact name match, description relevance, code snippet count, source reputation (High/Medium preferred), and benchmark score (higher is better). If results don't look right, try alternate names or queries (e.g., "next.js" not "nextjs", or rephrase the question)
    3. Fetch docs: `npx ctx7@latest docs <libraryId> "<user's question>"`
    4. Answer using the fetched documentation

    You MUST call `library` first to get a valid ID unless the user provides one directly in `/org/project` format. Use the user's full question as the query -- specific and detailed queries return better results than vague single words. Do not run more than 3 commands per question. Do not include sensitive information (API keys, passwords, credentials) in queries.

    For version-specific docs, use `/org/project/version` from the `library` output (e.g., `/vercel/next.js/v14.3.0`).

    If a command fails with a quota error, inform the user and suggest `npx ctx7@latest login` or setting `CONTEXT7_API_KEY` env var for higher limits. Do not silently fall back to training data.
    Run Context7 CLI requests outside Codex's default sandbox. If a Context7 CLI command fails with DNS or network errors such as ENOTFOUND, host resolution failures, or fetch failed, rerun it outside the sandbox instead of retrying inside the sandbox.
    <!-- context7 -->
  '';

  home.file.".local/bin/agent-skills-sync" = {
    source = ../../config/agent-skills-sync;
    executable = true;
  };

  # 既存 ~/.codex/config.toml に共有11キーのみ上書きマージする (chezmoi modify-template 相当)
  home.activation.codex-merge = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    conf="$HOME/.codex/config.toml"
    tmp=$(mktemp)
    trap 'rm -f "$tmp"' EXIT
    if [[ -f "$conf" ]]; then
      if ! ${pkgs.remarshal}/bin/remarshal -f toml -t json < "$conf" \
          | ${lib.getBin pkgs.jq}/bin/jq '${codexSharedKeys}' \
          | ${pkgs.remarshal}/bin/remarshal -f json -t toml > "$tmp"; then
        echo "codex-merge: failed to merge shared keys into $conf" >&2
        exit 1
      fi
    else
      # 新規ホスト: 共有キーのみの config をシードする (chezmoi modify_ と同挙動)
      if ! printf '{}' | ${lib.getBin pkgs.jq}/bin/jq '${codexSharedKeys}' \
          | ${pkgs.remarshal}/bin/remarshal -f json -t toml > "$tmp"; then
        echo "codex-merge: failed to seed $conf" >&2
        exit 1
      fi
    fi
    $DRY_RUN_CMD mv "$tmp" "$conf"
  '';

  # init/run_after_90_sync_agent_skills.sh.tmpl 相当
  home.activation.skills-sync = lib.hm.dag.entryAfter [ "codex-merge" ] ''
    if command -v mise >/dev/null 2>&1; then
      $DRY_RUN_CMD mise install apm uv
      $DRY_RUN_CMD mise exec -- uv run --script "$HOME/.local/bin/agent-skills-sync"
    fi
  '';
}
