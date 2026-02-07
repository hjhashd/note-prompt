import { onMounted } from 'vue'

export function usePerformance() {
  const isLowEndDevice = () => {
    // Simple heuristic: low concurrency or low memory
    const concurrency = navigator.hardwareConcurrency || 4
    // @ts-ignore
    const memory = navigator.deviceMemory || 4
    
    return concurrency <= 4 || memory <= 4
  }

  const initPerformanceMonitoring = () => {
    // Add class for low-end devices
    if (isLowEndDevice()) {
      document.body.classList.add('low-end-device')
      console.log('Low-end device detected: reducing animations')
    }

    // Monitor FCP
    const observer = new PerformanceObserver((entryList) => {
      for (const entry of entryList.getEntries()) {
        if (entry.name === 'first-contentful-paint') {
          console.log('FCP:', entry.startTime)
          // Here you would send to analytics
        }
      }
    })
    observer.observe({ type: 'paint', buffered: true })

    // Monitor LCP
    const lcpObserver = new PerformanceObserver((entryList) => {
      const entries = entryList.getEntries()
      const lastEntry = entries[entries.length - 1]
      console.log('LCP:', lastEntry.startTime)
    })
    lcpObserver.observe({ type: 'largest-contentful-paint', buffered: true })
  }

  const measureInteraction = (name: string, fn: () => void | Promise<void>) => {
    const start = performance.now()
    const result = fn()
    
    if (result instanceof Promise) {
      return result.finally(() => {
        const duration = performance.now() - start
        console.log(`Interaction [${name}]: ${duration.toFixed(2)}ms`)
      })
    } else {
      const duration = performance.now() - start
      console.log(`Interaction [${name}]: ${duration.toFixed(2)}ms`)
      return result
    }
  }

  return {
    isLowEndDevice,
    initPerformanceMonitoring,
    measureInteraction
  }
}
