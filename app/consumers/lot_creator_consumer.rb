class LotCreatorConsumer
  def call(message)
    @json_rpc_endpoint = URI.parse("http://35.195.174.216:8545")
    @json_rpc_call_id = 0
    issuer_address = ENV['ISSUER_ADDRESS']
    issuer_secret = ENV['ISSUER_SECRET']
    contract_address = ENV['CONTRACT_ADDRESS']

    lot = Lot.find(message['lot_id'])
    bid_increment = 10
    time_increment = 10
    bid_fee = 10

    permit_transaction(issuer_address, issuer_secret)

    data = abi_encode \
      'transfer(address,uint256)',
      '0x' + lot.start_price.to_s,
      '0x' + bid_increment.to_s,
      '0x' + time_increment.to_s,
      '0x' + bid_fee.to_s

      json_rpc(
        :eth_sendTransaction,
        [{
          from: normalize_address(issuer_address),
          to:   normalize_address(contract_address),
          data: data
        }]
      ).fetch('result').yield_self do |txid|
        normalize_txid(txid)
      end
  end

  def normalize_address(address)
    address.downcase
  end

  def normalize_txid(txid)
    txid.downcase
  end

  def abi_encode(method, *args)
    '0x' + args.each_with_object(Digest::SHA3.hexdigest(method, 256)[0...8]) do |arg, data|
      data.concat(arg.gsub(/\A0x/, '').rjust(64, '0'))
    end
  end

  def permit_transaction(issuer_address, issuer_secret)
    json_rpc(:personal_unlockAccount, [normalize_address(issuer_address), issuer_secret, 5]).tap do |response|
      unless response['result']
        raise StandardError, 'not permitted'
      end
    end
  end

  def connection
    Faraday.new(@json_rpc_endpoint).tap do |connection|
      unless @json_rpc_endpoint.user.blank?
        connection.basic_auth(@json_rpc_endpoint.user, @json_rpc_endpoint.password)
      end
    end
  end

  def json_rpc(method, params = [])
    response = connection.post \
      '/',
      { jsonrpc: '2.0', id: @json_rpc_call_id += 1, method: method, params: params }.to_json,
      { 'Accept'       => 'application/json',
        'Content-Type' => 'application/json' }
    # response.assert_success!
    response = JSON.parse(response.body)
    response['error'].tap { |error| raise StandardError, error.inspect if error }
    response
  end
end
