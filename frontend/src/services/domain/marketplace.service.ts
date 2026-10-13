import { request } from '../infra/http'
import type { ApiCharacterListing } from '../types'

export const marketplaceApi = {
  catalog: () => request<ApiCharacterListing[]>('/public/marketplace/'),
  mine: () => request<ApiCharacterListing[]>('/customer/marketplace/'),
  list: (payload: { char_id: number; price: string; login?: string; notes?: string }) =>
    request<ApiCharacterListing>('/customer/marketplace/', {
      method: 'POST',
      body: JSON.stringify(payload),
    }),
  buy: (listingId: string, destination_login?: string) =>
    request<ApiCharacterListing>(`/customer/marketplace/${listingId}/buy/`, {
      method: 'POST',
      ...(destination_login ? { body: JSON.stringify({ destination_login }) } : {}),
    }),
  cancel: (listingId: string) =>
    request<ApiCharacterListing>(`/customer/marketplace/${listingId}/cancel/`, { method: 'POST' }),
}
