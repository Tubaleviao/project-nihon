function safeMerge(noun, ...sources) {
  if (typeof noun !== 'string') throw new Error(`safeMerge: first argument must be a noun string (e.g. 'skill'), got ${typeof noun}`)
  return sources.reduce((acc, src) => {
    for (const key of Object.keys(src)) {
      if (Object.hasOwn(acc, key)) throw new Error(`Duplicate ${noun} entity key: "${key}"`)
      acc[key] = src[key]
    }
    return acc
  }, {})
}

module.exports = { safeMerge }
