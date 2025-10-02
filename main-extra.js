// This script reads sing-box-subscribe/config.json and:
// 1) Ensures any outbound object with tag === "my" or "au" has detour: "all".
// 2) Removes entries "au" or "my" from any selector outbound whose tag === "all".

const fs = require("fs");
const path = require("path");

const CONFIG_PATH = path.join(__dirname, "sing-box-subscribe", "config.json");

function loadConfig(filePath) {
  const raw = fs.readFileSync(filePath, "utf8");
  return JSON.parse(raw);
}

function saveConfig(filePath, data) {
  const formatted = JSON.stringify(data, null, 2);
  fs.writeFileSync(filePath, formatted + "\n", "utf8");
}

function ensureDetourForMyAu(config) {
  let updated = 0;

  const visit = (node) => {
    if (!node || typeof node !== "object") return;

    // If this node appears to be an outbound object with a tag
    if (typeof node.tag === "string" && (node.tag === "my" || node.tag === "au")) {
      if (node.detour !== "all") {
        node.detour = "all";
        updated += 1;
      }
    }

    // Recurse into object properties to catch nested structures.
    for (const key of Object.keys(node)) {
      const value = node[key];
      if (value && typeof value === "object") {
        if (Array.isArray(value)) {
          for (const item of value) visit(item);
        } else {
          visit(value);
        }
      }
    }
  };

  visit(config);
  return updated;
}

function removeAuMyFromAllSelector(config) {
  let removed = 0;

  const visit = (node) => {
    if (!node || typeof node !== "object") return;

    // Match an outbound selector with tag === "all"
    if (node.tag === "all" && Array.isArray(node.outbounds)) {
      const before = node.outbounds.length;
      node.outbounds = node.outbounds.filter((v) => {
        // Only filter string entries exactly matching "au" or "my"
        return !(typeof v === "string" && (v === "au" || v === "my"));
      });
      removed += before - node.outbounds.length;
    }

    // Recurse into object properties to catch nested structures.
    for (const key of Object.keys(node)) {
      const value = node[key];
      if (value && typeof value === "object") visit(value);
    }
  };

  visit(config);
  return removed;
}

async function updateGist(gistId, options) {
  const { files, description, token } = options;

  const formattedFiles = {};
  for (const [filename, content] of Object.entries(files)) {
    formattedFiles[filename] = {
      content: typeof content === "string" ? content : JSON.stringify(content, null, 2),
    };
  }

  const payload = {
    description,
    files: formattedFiles,
    public: false,
  };

  const apiUrl = "https://api.github.com/gists";
  try {
    const response = await fetch(`${apiUrl}/${gistId}`, {
      method: "PATCH",
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: "application/vnd.github.v3+json",
        "Content-Type": "application/json",
        "X-GitHub-Api-Version": "2022-11-28",
      },
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      let msg = `${response.status}`;
      try {
        const err = await response.json();
        if (err && err.message) msg += ` - ${err.message}`;
      } catch (_) {}
      throw new Error(`GitHub API error: ${msg}`);
    }

    return await response.json();
  } catch (error) {
    throw new Error(`Failed to update gist: ${error.message}`);
  }
}

function main() {
  const config = loadConfig(CONFIG_PATH);
  const detourUpdates = ensureDetourForMyAu(config);
  const removed = removeAuMyFromAllSelector(config);

  if (detourUpdates > 0 || removed > 0) {
    saveConfig(CONFIG_PATH, config);
  }

  console.log(
    `Detour updates: ${detourUpdates}; removed from 'all': ${removed}.`
  );

  // Always upload the current config.json to Gist as "singbox".
  const gistId = process.env.GIST_ID;
  const token = process.env.GIST_TOKEN;
  if (!gistId || !token) {
    console.error("GIST_ID or GIST_TOKEN not set; skipping Gist upload.");
    return;
  }

  try {
    const raw = fs.readFileSync(CONFIG_PATH, "utf8");
    updateGist(gistId, {
      files: { singbox: raw },
      description: "",
      token,
    })
      .then(() => console.log("Gist updated with singbox config"))
      .catch((err) => console.error("Error updating gist:", err.message));
  } catch (e) {
    console.error("Failed to read config for upload:", e.message);
  }
}

main();
