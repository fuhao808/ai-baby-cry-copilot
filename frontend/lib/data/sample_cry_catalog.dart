import '../models/sample_cry.dart';

const sampleCryCatalog = <SampleCry>[
  SampleCry(
    id: 'hungry',
    title: 'Hungry',
    pattern: '"Neh"',
    summary:
        'The "N" sound is often linked to a sucking reflex, with the tongue moving toward the roof of the mouth.',
    visualCues: 'Rooting reflex, sucking hands, smacking lips.',
    assetPath: 'assets/samples/hungry_sample.wav',
    fileName: 'hungry_sample.wav',
  ),
  SampleCry(
    id: 'sleepy',
    title: 'Sleepy',
    pattern: '"Owh"',
    summary:
        'This softer pattern often shows up around a yawn-like mouth shape when a baby is winding down.',
    visualCues: 'Rubbing eyes, zoning out, slower blinking, harder settling.',
    assetPath: 'assets/samples/sleepy_sample.wav',
    fileName: 'sleepy_sample.wav',
  ),
  SampleCry(
    id: 'pain_gas',
    title: 'Pain / Gas',
    pattern: '"Eairh"',
    summary:
        'This tighter, more strained sound is commonly associated with belly pressure or a tense discomfort response.',
    visualCues: 'Leg tucking, arching back, sudden tension, grimacing.',
    assetPath: 'assets/samples/pain_gas_sample.wav',
    fileName: 'pain_gas_sample.wav',
  ),
  SampleCry(
    id: 'fussy',
    title: 'Fussy / Discomfort',
    pattern: '"Heh"',
    summary:
        'This lighter, irregular complaint sound often appears when the baby is generally uncomfortable rather than urgently distressed.',
    visualCues: 'Squirming, restlessness, overstimulation, position discomfort.',
    assetPath: 'assets/samples/fussy_sample.wav',
    fileName: 'fussy_sample.wav',
  ),
];
