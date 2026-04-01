import '../models/sample_cry.dart';

const sampleCryCatalog = <SampleCry>[
  SampleCry(
    id: 'hungry',
    title: 'Hungry',
    topLabel: 'Hungry',
    soundLike: 'Often described as "neh" or a short urgent rooting cry',
    summary:
        'Usually rhythmic, escalating, and paired with rooting, lip-smacking, or searching for the bottle or breast.',
    details: [
      'The cry may repeat in short bursts and build if feeding is delayed.',
      'Look for turning the head side to side or bringing hands toward the mouth.',
      'This sample is bundled for quick MVP testing only, not as clinical ground truth.',
    ],
    assetPath: 'assets/samples/hungry_sample.wav',
    fileName: 'hungry_sample.wav',
  ),
  SampleCry(
    id: 'sleepy',
    title: 'Sleepy',
    topLabel: 'Sleepy',
    soundLike: 'Often described as "owh" with a yawning or fading quality',
    summary:
        'Usually softer or wavering, and often shows up when the baby is overstimulated, rubbing eyes, or struggling to settle.',
    details: [
      'The pattern may sound more breathy or tired than urgent.',
      'A winding-down routine, dim light, or swaddle may help if the baby is otherwise comfortable.',
      'This sample is bundled for quick MVP testing only, not as clinical ground truth.',
    ],
    assetPath: 'assets/samples/sleepy_sample.wav',
    fileName: 'sleepy_sample.wav',
  ),
  SampleCry(
    id: 'pain_gas',
    title: 'Pain / Gas',
    topLabel: 'Pain/Gas',
    soundLike: 'Often described as "eairh" or strained "er-er" tension',
    summary:
        'This pattern is often sharper, tighter, or more sudden, and may come with leg tucking, arching, or obvious discomfort.',
    details: [
      'Burping, bicycle legs, and checking pressure points like diaper and clothing are good first actions.',
      'If a cry sounds unusual, persistent, or extreme, caregivers should not rely on an app alone.',
      'This sample is bundled for quick MVP testing only, not as clinical ground truth.',
    ],
    assetPath: 'assets/samples/pain_gas_sample.wav',
    fileName: 'pain_gas_sample.wav',
  ),
  SampleCry(
    id: 'fussy',
    title: 'Fussy / Discomfort',
    topLabel: 'Fussy',
    soundLike: 'Often described as "heh" or a restless complaint cry',
    summary:
        'This category covers common general discomfort: temperature, clothing, overstimulation, position, or a need for soothing contact.',
    details: [
      'The cry may sound irritated or irregular rather than strongly tied to one need.',
      'Try reducing stimulation, changing position, checking temperature, and offering gentle holding.',
      'This sample is bundled for quick MVP testing only, not as clinical ground truth.',
    ],
    assetPath: 'assets/samples/fussy_sample.wav',
    fileName: 'fussy_sample.wav',
  ),
];
