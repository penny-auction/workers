# frozen_string_literal: true

class BidCreatedConsumer
  def call(message)
    bid_obj = find_bid(message)

    geth_service = SmartContractService.new
    geth_service.create_bid(bid_obj.lot_id, bid_obj.depositor_uid).tap do |txid|
      Rails.logger.info { "Bid creation txid: #{txid}" }
    end

    bid_obj.update(state: :published)
  end

  private

  def find_bid(message)
    Rails.logger.info { "BidCreatedConsumer receive message #{message}" }

    bid_id = message[:bid_id] || message['bid_id']
    unless bid_id
      Rails.logger.warn { "BidCreatedConsumer can't process message #{message}" }
      return
    end

    bid_obj = Bid.find_by_id(bid_id)
    unless bid_obj
      Rails.logger.warn { "Skipped bid with id: #{bid_id}. Doesn't exist in db" }
      return
    end

    unless bid_obj.state == 'created'
      Rails.logger.warn { "Skipped bid with id: #{bid_id}. Bid state != created" }
      return
    end
    bid_obj
  end
end
