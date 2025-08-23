

import * as yaml from "js-yaml"
import "fs"
import { readFileSync } from "fs"

const file = yaml.load(readFileSync("./output.yaml", "utf8"))

const updateGist = async (gistId, options) => {
    const { files, description, token } = options;
    
    const formattedFiles = {};
    for (const [filename, content] of Object.entries(files)) {
        formattedFiles[filename] = {
            content: typeof content === 'string' ? content : JSON.stringify(content, null, 2)
        };
    }

    const payload = {
        description,
        files: formattedFiles,
        public: false
    };
    const apiUrl = 'https://api.github.com/gists'

    try {
        console.log(`${apiUrl}/${gistId}`)
        const response = await fetch(`${apiUrl}/${gistId}`, {
            method: 'PATCH',
            headers: {
                'Authorization': `Bearer ${token}`,
                'Accept': 'application/vnd.github.v3+json',
                'Content-Type': 'application/json',
                'X-GitHub-Api-Version': '2022-11-28'
            },
            body: JSON.stringify(payload)
        });

        if (!response.ok) {
            const error = await response.json();
            throw new Error(`GitHub API error: ${response.status} - ${error.message}`);
        }

        return await response.json();
    } catch (error) {
        throw new Error(`Failed to update gist: ${error.message}`);
    }
}

updateGist(process.env.GIST_ID, { 
    files: {
        "clash": yaml.dump(main(file)),
    }, 
    description: "",
    token: process.env.GIST_TOKEN }).then(res => {
        console.log("Gist updated:", res.html_url);
    }).catch(err => {
        console.error("Error updating gist:", err.message);
    });
