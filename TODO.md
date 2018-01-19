- [ ] Allow one to pause values observation, and restart with fresh values
- [ ] Rename "change tokens" into "fetch tokens", as a support for the "changes observable" vs. "values observables" dichotomy. After this change, changes observables are observables that have "changes" in their names, and values observables are observables that have "fetch" in their name:
    
    ```swift
    // A changes observable
    request.rx.changes(in:...)...
    
    // A changes observable
    dbQueue.rx.changes(in:...)...
    
    // A values observable
    request.rx.fetchAll(in:...)
    
    // A values observable
    dbQueue.rx.fetchTokens(in:...).mapFetch(...)...
    ```
