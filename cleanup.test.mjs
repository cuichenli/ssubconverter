import assert from "node:assert/strict"
import test from "node:test"
import { cleanInvalidHysteriaProxies } from "./cleanup.mjs"

test("removes Hysteria 1 proxies without speeds and their group references", () => {
    const config = {
        proxies: [
            { name: "valid-hysteria", type: "hysteria", up: "30 Mbps", down: "200 Mbps" },
            { name: "missing-upload", type: "hysteria", up: "", down: "200 Mbps" },
            { name: "invalid-hysteria", type: "hysteria", up: "not-a-speed", down: "200 Mbps" },
            { name: "zero-speed", type: "hysteria", up: "0", down: "200 Mbps" },
            { name: "hysteria2", type: "hysteria2", up: "", down: "" }
        ],
        "proxy-groups": [
            {
                name: "auto",
                type: "select",
                proxies: [
                    "valid-hysteria",
                    "missing-upload",
                    "invalid-hysteria",
                    "zero-speed",
                    "hysteria2",
                    "DIRECT"
                ]
            }
        ]
    }

    const cleaned = cleanInvalidHysteriaProxies(config)

    assert.deepEqual(cleaned.proxies.map(proxy => proxy.name), ["valid-hysteria", "hysteria2"])
    assert.deepEqual(cleaned["proxy-groups"][0].proxies, ["valid-hysteria", "hysteria2", "DIRECT"])
})

test("preserves configs without invalid Hysteria 1 proxies", () => {
    const config = {
        proxies: [
            { name: "valid-hysteria", type: "hysteria", up: "30 Mbps", down: "200 Mbps" }
        ],
        "proxy-groups": []
    }

    assert.strictEqual(cleanInvalidHysteriaProxies(config), config)
})
