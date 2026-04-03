import '../models/sample_cry.dart';

const sampleCryCatalog = <SampleCry>[
  SampleCry(
    id: 'hungry',
    title: 'Hungry',
    topLabel: 'Hungry',
    soundLike: '"Neh"',
    summary:
        'Usually rhythmic, escalating, and paired with rooting, lip-smacking, or searching for the bottle or breast.',
    details: [
      'The cry may repeat in short bursts and build if feeding is delayed.',
      'Look for turning the head side to side or bringing hands toward the mouth.',
      'The "N" sound is often linked to a sucking reflex, with the tongue moving toward the roof of the mouth.',
    ],
    visualCue: 'Rooting reflex, sucking hands, smacking lips.',
    assetPath: 'assets/samples/hungry_sample.wav',
    fileName: 'hungry_sample.wav',
    previewStartSeconds: 0.0,
  ),
  SampleCry(
    id: 'sleepy',
    title: 'Sleepy',
    topLabel: 'Sleepy',
    soundLike: '"Owh"',
    summary:
        'Usually softer or wavering, and often shows up when the baby is overstimulated, rubbing eyes, or struggling to settle.',
    details: [
      'The pattern may sound more breathy or tired than urgent.',
      'A winding-down routine, dim light, or swaddle may help if the baby is otherwise comfortable.',
      'This cue often appears around a yawn-like mouth shape when a baby is drifting toward sleep.',
    ],
    visualCue: 'Rubbing eyes, zoning out, slower blinking, harder settling.',
    assetPath: 'assets/samples/sleepy_sample.wav',
    fileName: 'sleepy_sample.wav',
    previewStartSeconds: 0.66,
  ),
  SampleCry(
    id: 'pain_gas',
    title: 'Pain / Gas',
    topLabel: 'Pain/Gas',
    soundLike: '"Eairh"',
    summary:
        'This pattern is often sharper, tighter, or more sudden, and may come with leg tucking, arching, or obvious discomfort.',
    details: [
      'Burping, bicycle legs, and checking pressure points like diaper and clothing are good first actions.',
      'If a cry sounds unusual, persistent, or extreme, caregivers should not rely on an app alone.',
      'The tighter "eairh" pattern is often associated with belly pressure or a tense discomfort response.',
    ],
    visualCue: 'Leg tucking, arching back, sudden tension, grimacing.',
    assetPath: 'assets/samples/pain_gas_sample.wav',
    fileName: 'pain_gas_sample.wav',
    previewStartSeconds: 0.0,
  ),
  SampleCry(
    id: 'fussy',
    title: 'Fussy / Discomfort',
    topLabel: 'Fussy',
    soundLike: '"Heh"',
    summary:
        'This category covers common general discomfort: temperature, clothing, overstimulation, position, or a need for soothing contact.',
    details: [
      'The cry may sound irritated or irregular rather than strongly tied to one need.',
      'Try reducing stimulation, changing position, checking temperature, and offering gentle holding.',
      'This lighter complaint pattern often appears when the baby is generally uncomfortable rather than urgently distressed.',
    ],
    visualCue: 'Squirming, restlessness, overstimulation, position discomfort.',
    assetPath: 'assets/samples/fussy_sample.wav',
    fileName: 'fussy_sample.wav',
    previewStartSeconds: 0.33,
  ),
];
