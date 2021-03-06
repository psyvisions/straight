module Straight
  module Blockchain

    class BlockchainInfoAdapter < Adapter

      def self.mainnet_adapter
        self.new("http://blockchain.info")
      end
      
      def self.testnet_adapter
        raise "Not Supported Yet"
      end
      
      def initialize(base_url)
        @latest_block = { cache_timestamp: nil, block: nil }
        @base_url = base_url
      end

      # Returns transaction info for the tid
      def fetch_transaction(tid, address: nil)
        straighten_transaction JSON.parse(http_request("#{@base_url}/rawtx/#{tid}"), address: address)
      end

      # Returns all transactions for the address
      def fetch_transactions_for(address)
        transactions = JSON.parse(http_request("#{@base_url}/rawaddr/#{address}"))['txs']
        transactions.map { |t| straighten_transaction(t, address: address) }
      end

      # Returns the current balance of the address
      def fetch_balance_for(address)
        JSON.parse(http_request("#{@base_url}/rawaddr/#{address}"))['final_balance']
      end

      private

        # Converts transaction info received from the source into the
        # unified format expected by users of BlockchainAdapter instances.
        def straighten_transaction(transaction, address: nil)
          outs         = []
          total_amount = 0
          transaction['out'].each do |out|
            total_amount += out['value'] if address.nil? || address == out['addr']
            outs << { amount: out['value'], receiving_address: out['addr'] }
          end

          {
            tid:           transaction['hash'],
            total_amount:  total_amount,
            confirmations: calculate_confirmations(transaction),
            outs:          outs
          }
        end


        # When we call #calculate_confirmations, it doesn't always make a new
        # request to the blockchain API. Instead, it checks if cached_id matches the one in
        # the hash. It's useful when we want to calculate confirmations for all transactions for
        # a certain address without making any new requests to the Blockchain API.
        def calculate_confirmations(transaction, force_latest_block_reload: false)

          # If we checked Blockchain.info latest block data
          # more than a minute ago, check again. Otherwise, use cached version.
          if @latest_block[:cache_timestamp].nil?              ||
             @latest_block[:cache_timestamp] < (Time.now - 60) ||
             force_latest_block_reload
            @latest_block = {
              cache_timestamp: Time.now,
              block: JSON.parse(http_request("#{@base_url}/latestblock"))
            }
          end

          if transaction["block_height"]
            @latest_block[:block]["height"] - transaction["block_height"] + 1
          else
            0
          end

        end

    end

  end
end
