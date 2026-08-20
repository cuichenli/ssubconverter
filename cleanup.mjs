const hasValidSpeed = value => {
    const speed = typeof value === "number" ? String(value) : value
    if (typeof speed !== "string") {
        return false
    }

    if (/^\d+$/.test(speed)) {
        return BigInt(speed) > 0n
    }

    const match = speed.match(/^(\d+)\s*([KMGT]?)([Bb])ps$/)
    if (!match) {
        return false
    }

    const multipliers = { "": 1n, K: 1000n, M: 1000000n, G: 1000000000n, T: 1000000000000n }
    const bitsPerSecond = BigInt(match[1]) * multipliers[match[2]]

    return match[3] === "b" ? bitsPerSecond / 8n > 0n : bitsPerSecond > 0n
}

export const cleanInvalidHysteriaProxies = config => {
    if (!config || !Array.isArray(config.proxies)) {
        return config
    }

    const removedProxyNames = new Set()
    const proxies = config.proxies.filter(proxy => {
        const invalidHysteria = proxy?.type === "hysteria" &&
            (!hasValidSpeed(proxy.up) || !hasValidSpeed(proxy.down))

        if (invalidHysteria && typeof proxy.name === "string") {
            removedProxyNames.add(proxy.name)
        }

        return !invalidHysteria
    })

    if (proxies.length === config.proxies.length) {
        return config
    }

    const cleanedConfig = {
        ...config,
        proxies
    }

    if (Array.isArray(config["proxy-groups"])) {
        cleanedConfig["proxy-groups"] = config["proxy-groups"].map(group => {
            if (!group || !Array.isArray(group.proxies)) {
                return group
            }

            return {
                ...group,
                proxies: group.proxies.filter(proxyName => !removedProxyNames.has(proxyName))
            }
        })
    }

    return cleanedConfig
}
