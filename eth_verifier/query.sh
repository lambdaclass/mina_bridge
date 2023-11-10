curl -d '{"query": "{
  bestChain(maxLength: 1) {
    creator
    stateHashField
    protocolState {
      consensusState {
        blockHeight
      }
    }
  }
}"}' -H 'Content-Type: application/json' http://5.9.57.89:3085/graphql
