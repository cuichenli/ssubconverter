// This script reads sing-box-subscribe/config.json, finds any outbound
// object with tag === "my", and adds/sets the field detour: "all".

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

function updateOutboundsDetour(config) {
  let modified = 0;

  const visit = (node) => {
    if (!node || typeof node !== "object") return;

    // If this node has an `outbounds` array, inspect its elements.
    if (Array.isArray(node.outbounds)) {
      for (const item of node.outbounds) {
        if (item && typeof item === "object" && (item.tag === "my" || item.tag === "au")) {
          if (item.detour !== "all") {
            item.detour = "all";
            modified += 1;
          }
        }
      }
    }

    // Recurse into all object properties to catch nested structures.
    for (const key of Object.keys(node)) {
      const value = node[key];
      if (value && typeof value === "object") visit(value);
    }
  };

  visit(config);
  return modified;
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
  const changes = updateOutboundsDetour(config);
  if (changes > 0) {
    saveConfig(CONFIG_PATH, config);
    console.log(`Updated detour=\"all\" on ${changes} outbound(s) tagged 'my'.`);
  } else {
    console.log("No matching outbound with tag 'my' found or already up to date.");
  }

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
