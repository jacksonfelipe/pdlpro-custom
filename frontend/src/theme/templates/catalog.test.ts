import { expect, it } from 'vitest'
import { THEME_CATALOG_IDS } from './ids'
import { PUBLIC_TEMPLATE_LIST, PUBLIC_TEMPLATES } from './catalog'
import { isCatalogRenderer, isGemwright, isVesperlyn, resolveTemplateId } from './resolve'

it('publica layouts clássicos e de cliente com id, nome e composição próprios', () => {
  expect(THEME_CATALOG_IDS).toHaveLength(21)
  expect(PUBLIC_TEMPLATE_LIST).toHaveLength(21)
  const compositions = PUBLIC_TEMPLATE_LIST.map((item) => item.composition)
  expect(new Set(compositions).size).toBe(21)
  const names = PUBLIC_TEMPLATE_LIST.map((item) => item.name)
  expect(new Set(names).size).toBe(21)
  expect(PUBLIC_TEMPLATES.vesperlyn.name).toBe('Vesperlyn')
  expect(PUBLIC_TEMPLATES.ironspine.composition).toBe('three-column-spine')
  expect(PUBLIC_TEMPLATES.wayfarer.composition).toBe('three-steps')
  expect(PUBLIC_TEMPLATES.hallowverde.composition).toBe('verdant-citadel')
})

it('resolve os aliases antigos sem exigir renderer novo no ZIP', () => {
  expect(resolveTemplateId('club-v1')).toBe('vesperlyn')
  expect(resolveTemplateId('portal-v1')).toBe('gemwright')
  expect(resolveTemplateId('ironspine')).toBe('ironspine')
  expect(resolveTemplateId('javascript')).toBeNull()
  expect(isVesperlyn('club-v1')).toBe(true)
  expect(isVesperlyn('vesperlyn')).toBe(true)
  expect(isGemwright('portal-v1')).toBe(true)
  expect(isCatalogRenderer('watchfire')).toBe(true)
  expect(isCatalogRenderer('hallowverde')).toBe(true)
  expect(isCatalogRenderer('javascript')).toBe(false)
})
